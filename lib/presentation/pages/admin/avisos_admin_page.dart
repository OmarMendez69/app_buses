import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Avisos de servicio. Al publicar uno con "Notificar", llega como push
/// a quien sigue la ruta (o a todos si es general) en segundos.
class AvisosAdminPage extends StatefulWidget {
  final AppViewModels vms;
  const AvisosAdminPage({super.key, required this.vms});

  @override
  State<AvisosAdminPage> createState() => _AvisosAdminPageState();
}

class _AvisosAdminPageState extends State<AvisosAdminPage> {
  late Future<List<Aviso>> _avisos;

  @override
  void initState() {
    super.initState();
    _avisos = widget.vms.admin.avisos();
  }

  void _recargar() => setState(() => _avisos = widget.vms.admin.avisos());

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos de servicio')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAcento,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AvisoFormPage(vms: widget.vms)));
          _recargar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo aviso'),
      ),
      body: FutureBuilder<List<Aviso>>(
        future: _avisos,
        builder: (context, snap) {
          if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!));
          if (!snap.hasData) return const Cargando();
          final ahora = DateTime.now();
          final lista = snap.data!;
          if (lista.isEmpty) return const EstadoVacio(mensaje: 'Sin avisos todavía');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              for (final a in lista)
                Card(
                  child: ListTile(
                    leading: Icon(a.automatico ? Icons.auto_mode : Icons.campaign_outlined, color: a.vigenteEn(ahora) ? kAmbar : kTextoSecundario),
                    title: Text(a.titulo),
                    subtitle: Text('${a.tipo.etiqueta} · ${cat.rutaPorId[a.idRuta]?.nombre ?? 'General'}\n'
                        '${a.vigenteEn(ahora) ? 'Vigente' : 'No vigente'} · ${fechaCorta(a.creadoEn)}${a.automatico ? ' · automático' : ''}'),
                    isThreeLine: true,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AvisoFormPage(vms: widget.vms, aviso: a)));
                      _recargar();
                    },
                    trailing: a.vigenteEn(ahora)
                        ? TextButton(
                            onPressed: () async {
                              try {
                                await widget.vms.admin.retirarAviso(a.id);
                                await widget.vms.catalogo.refrescar();
                                _recargar();
                              } catch (e) {
                                if (context.mounted) avisar(context, mensajeError(e));
                              }
                            },
                            child: const Text('Retirar'),
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AvisoFormPage extends StatefulWidget {
  final AppViewModels vms;
  final Aviso? aviso;

  /// Datos para llenar un aviso nuevo (p. ej. desde los reportes de la comunidad).
  final int? idRutaInicial;
  final TipoAviso? tipoInicial;
  final String? tituloInicial;
  final String? detalleInicial;
  final Set<int> paradasIniciales;

  const AvisoFormPage({
    super.key,
    required this.vms,
    this.aviso,
    this.idRutaInicial,
    this.tipoInicial,
    this.tituloInicial,
    this.detalleInicial,
    this.paradasIniciales = const {},
  });

  @override
  State<AvisoFormPage> createState() => _AvisoFormPageState();
}

class _AvisoFormPageState extends State<AvisoFormPage> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _detalle = TextEditingController();
  TipoAviso _tipo = TipoAviso.desvio;
  int? _ruta;
  final Set<int> _paradas = {};
  DateTime _desde = DateTime.now();
  DateTime? _hasta;
  bool _notificar = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final a = widget.aviso;
    if (a != null) {
      _titulo.text = a.titulo;
      _detalle.text = a.detalle;
      _tipo = a.tipo;
      _ruta = a.idRuta;
      _paradas.addAll(a.paradasAfectadas);
      _desde = a.vigenteDesde;
      _hasta = a.vigenteHasta;
      _notificar = false; // editar no vuelve a notificar
    } else {
      _ruta = widget.idRutaInicial;
      _tipo = widget.tipoInicial ?? _tipo;
      _titulo.text = widget.tituloInicial ?? '';
      _detalle.text = widget.detalleInicial ?? '';
      _paradas.addAll(widget.paradasIniciales);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<DateTime?> _fechaHora(DateTime inicial) async {
    final f = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (f == null || !mounted) return null;
    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(inicial));
    if (h == null) return null;
    return DateTime(f.year, f.month, f.day, h.hour, h.minute);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_hasta != null && !_hasta!.isAfter(_desde)) {
      avisar(context, 'La vigencia debe terminar después de empezar.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final datos = {
        'id_ruta': _ruta,
        'tipo': _tipo.db,
        'titulo': _titulo.text.trim(),
        'detalle': _detalle.text.trim(),
        'vigente_desde': _desde.toUtc().toIso8601String(),
        'vigente_hasta': _hasta?.toUtc().toIso8601String(),
        if (widget.aviso == null) 'notificar': _notificar,
        if (widget.aviso == null) 'creado_por': widget.vms.sesion.perfil?.id,
      };
      await widget.vms.admin.guardarAviso(datos, _paradas.toList(), id: widget.aviso?.id);
      await widget.vms.catalogo.refrescar();
      if (mounted) {
        avisar(context, widget.aviso == null && _notificar ? 'Aviso publicado y notificado' : 'Aviso guardado');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final paradasRuta = _ruta == null
        ? cat.paradas
        : cat.paradas.where((p) => cat.geosDeRuta(_ruta!).any((g) => g.recorrido.paradas.any((x) => x.idParada == p.id))).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.aviso == null ? 'Nuevo aviso' : 'Editar aviso')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<TipoAviso>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo', filled: true, fillColor: kSuperficie),
              items: [for (final t in TipoAviso.values) DropdownMenuItem(value: t, child: Text(t.etiqueta))],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: _ruta,
              decoration: const InputDecoration(labelText: 'Ruta', filled: true, fillColor: kSuperficie),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('General (toda la ciudad)')),
                for (final r in cat.rutas) DropdownMenuItem<int?>(value: r.id, child: Text(r.nombre)),
              ],
              onChanged: (v) => setState(() {
                _ruta = v;
                _paradas.clear();
              }),
            ),
            const SizedBox(height: 10),
            CampoTexto(controller: _titulo, etiqueta: 'Título', icono: Icons.title, validator: Validadores.requerido, maximo: 80),
            const SizedBox(height: 10),
            CampoTexto(controller: _detalle, etiqueta: 'Detalle y recorrido alterno', icono: Icons.notes, lineas: 4),
            const TituloSeccion('Paradas afectadas'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in paradasRuta)
                FilterChip(
                  label: Text(p.nombre),
                  selected: _paradas.contains(p.id),
                  onSelected: (v) => setState(() => v ? _paradas.add(p.id) : _paradas.remove(p.id)),
                ),
            ]),
            const TituloSeccion('Vigencia'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desde'),
              trailing: Text(fechaCorta(_desde)),
              onTap: () async {
                final d = await _fechaHora(_desde);
                if (d != null) setState(() => _desde = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hasta'),
              trailing: Text(_hasta == null ? 'Sin fecha de fin' : fechaCorta(_hasta!)),
              onTap: () async {
                final d = await _fechaHora(_hasta ?? _desde.add(const Duration(days: 1)));
                if (d != null) setState(() => _hasta = d);
              },
              onLongPress: () => setState(() => _hasta = null),
            ),
            if (widget.aviso == null)
              SwitchListTile(
                title: const Text('Notificar al publicar'),
                subtitle: Text(_ruta == null ? 'Llega a todos los que tienen activados los avisos generales' : 'Llega a quien sigue esta ruta'),
                value: _notificar,
                activeTrackColor: kAcento,
                onChanged: (v) => setState(() => _notificar = v),
              ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
              onPressed: _guardando ? null : _guardar,
              child: Text(widget.aviso == null ? 'Publicar aviso' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
