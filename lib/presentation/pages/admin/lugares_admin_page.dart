import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';

/// Lugares de interés y sus horarios (de aquí sale la Hora pico).
class LugaresAdminPage extends StatelessWidget {
  final AppViewModels vms;
  const LugaresAdminPage({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lugares y sus horarios')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAcento,
        onPressed: () => abrir(context, LugarFormPage(vms: vms)),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: vms.catalogo,
        builder: (context, _) {
          final cat = vms.catalogo.cat;
          final lista = [...cat.lugares]..sort((a, b) => a.nombre.compareTo(b.nombre));
          if (lista.isEmpty) return const EstadoVacio(mensaje: 'Agrega escuelas, hospital, oficinas, mercado, museos…');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final l in lista)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.place_outlined, color: l.activo ? kAcento : kTextoSecundario),
                    title: Text(l.nombre),
                    subtitle: Text('${l.categoria.etiqueta} · ${cat.horarios.where((h) => h.idLugar == l.id).length} horarios${l.activo ? '' : ' · INACTIVO'}'),
                    onTap: () => abrir(context, LugarFormPage(vms: vms, lugar: l)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LugarFormPage extends StatefulWidget {
  final AppViewModels vms;
  final Lugar? lugar;
  const LugarFormPage({super.key, required this.vms, this.lugar});

  @override
  State<LugarFormPage> createState() => _LugarFormPageState();
}

class _LugarFormPageState extends State<LugarFormPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  CategoriaLugar _categoria = CategoriaLugar.educacion;
  LatLng? _punto;
  bool _activo = true;

  @override
  void initState() {
    super.initState();
    final l = widget.lugar;
    if (l != null) {
      _nombre.text = l.nombre;
      _categoria = l.categoria;
      _punto = l.punto;
      _activo = l.activo;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_punto == null) {
      avisar(context, 'Marca la ubicación en el mapa.');
      return;
    }
    try {
      await widget.vms.admin.guardarLugar({
        'nombre': _nombre.text.trim(),
        'categoria': _categoria.db,
        'latitud': double.parse(_punto!.latitude.toStringAsFixed(6)),
        'longitud': double.parse(_punto!.longitude.toStringAsFixed(6)),
        'activo': _activo,
      }, id: widget.lugar?.id);
      await widget.vms.catalogo.refrescar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _agregarHorario() async {
    TipoDia td = TipoDia.laborable;
    int? diaSemana;
    TimeOfDay hora = const TimeOfDay(hour: 7, minute: 0);
    TipoEvento evento = TipoEvento.entrada;
    String fuente = 'institucion';
    final descripcion = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Nuevo horario'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<TipoDia>(
                initialValue: td,
                decoration: const InputDecoration(labelText: 'Tipo de día'),
                items: [for (final t in TipoDia.values) DropdownMenuItem(value: t, child: Text(t.etiqueta))],
                onChanged: (v) => set(() => td = v ?? td),
              ),
              DropdownButtonFormField<int?>(
                initialValue: diaSemana,
                decoration: const InputDecoration(labelText: 'Solo un día (ej. tianguis)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Todos los días de ese tipo')),
                  for (var d = 1; d <= 7; d++) DropdownMenuItem<int?>(value: d, child: Text(nombreDiaSemana(d))),
                ],
                onChanged: (v) => set(() => diaSemana = v),
              ),
              DropdownButtonFormField<TipoEvento>(
                initialValue: evento,
                decoration: const InputDecoration(labelText: 'Evento'),
                items: [for (final e in TipoEvento.values) DropdownMenuItem(value: e, child: Text(e.etiqueta))],
                onChanged: (v) => set(() => evento = v ?? evento),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora'),
                trailing: Text(textoHora(hora.hour * 60 + hora.minute)),
                onTap: () async {
                  final h = await showTimePicker(context: c, initialTime: hora);
                  if (h != null) set(() => hora = h);
                },
              ),
              TextField(controller: descripcion, decoration: const InputDecoration(labelText: 'Descripción (ej. turno matutino)')),
              DropdownButtonFormField<String>(
                initialValue: fuente,
                decoration: const InputDecoration(labelText: 'Fuente'),
                items: const [
                  DropdownMenuItem(value: 'institucion', child: Text('La institución')),
                  DropdownMenuItem(value: 'oficial', child: Text('Oficial')),
                  DropdownMenuItem(value: 'municipio', child: Text('Municipio')),
                  DropdownMenuItem(value: 'levantamiento', child: Text('Levantamiento en campo')),
                ],
                onChanged: (v) => set(() => fuente = v ?? fuente),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Agregar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.vms.admin.agregarHorario({
        'id_lugar': widget.lugar!.id,
        'tipo_dia': td.db,
        'dia_semana': diaSemana,
        'hora': '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
        'evento': evento.db,
        'descripcion': descripcion.text.trim().isEmpty ? null : descripcion.text.trim(),
        'fuente': fuente,
      });
      await widget.vms.catalogo.refrescar();
      setState(() {});
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final horarios = widget.lugar == null ? <HorarioLugar>[] : (cat.horarios.where((h) => h.idLugar == widget.lugar!.id).toList()..sort((a, b) => a.hora.compareTo(b.hora)));

    return Scaffold(
      appBar: AppBar(title: Text(widget.lugar == null ? 'Nuevo lugar' : 'Editar lugar')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CampoTexto(controller: _nombre, etiqueta: 'Nombre', icono: Icons.place_outlined, validator: Validadores.requerido, maximo: 100),
            const SizedBox(height: 10),
            DropdownButtonFormField<CategoriaLugar>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría', filled: true, fillColor: kSuperficie),
              items: [for (final c in CategoriaLugar.values) DropdownMenuItem(value: c, child: Text(c.etiqueta))],
              onChanged: (v) => setState(() => _categoria = v ?? _categoria),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MapaBase(
                  centro: _punto,
                  zoom: 16,
                  alTocar: (p) => setState(() => _punto = p),
                  capas: [if (_punto != null) MarkerLayer(markers: [marcadorIcono(_punto!, Icons.location_on, kAcento)])],
                ),
              ),
            ),
            const Text('Toca el mapa para ubicar el lugar.', style: TextStyle(color: kTextoSecundario, fontSize: 12)),
            SwitchListTile(title: const Text('Activo'), value: _activo, activeTrackColor: kAcento, onChanged: (v) => setState(() => _activo = v)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
              onPressed: _guardar,
              child: const Text('Guardar lugar'),
            ),
            if (widget.lugar != null) ...[
              const TituloSeccion('Horarios (alta demanda)'),
              for (final h in horarios)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${textoHora(h.hora)} · ${h.evento.etiqueta}${h.descripcion == null ? '' : ' · ${h.descripcion}'}'),
                  subtitle: Text('${h.tipoDia.etiqueta}${h.diaSemana == null ? '' : ' (${nombreDiaSemana(h.diaSemana!)})'} · Fuente: ${etiquetaFuente(h.fuente)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await widget.vms.admin.borrarHorario(h.id);
                        await widget.vms.catalogo.refrescar();
                        setState(() {});
                      } catch (e) {
                        if (context.mounted) avisar(context, mensajeError(e));
                      }
                    },
                  ),
                ),
              TextButton.icon(onPressed: _agregarHorario, icon: const Icon(Icons.add_alarm), label: const Text('Agregar horario')),
            ],
          ],
        ),
      ),
    );
  }
}
