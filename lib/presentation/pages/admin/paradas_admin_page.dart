import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_colors.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import '../../widgets/selector_punto.dart';

class ParadasAdminPage extends StatefulWidget {
  final AppViewModels vms;
  const ParadasAdminPage({super.key, required this.vms});

  @override
  State<ParadasAdminPage> createState() => _ParadasAdminPageState();
}

class _ParadasAdminPageState extends State<ParadasAdminPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paradas')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAcento,
        onPressed: () => abrir(context, ParadaFormPage(vms: widget.vms)),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: widget.vms.catalogo,
        builder: (context, _) {
          final cat = widget.vms.catalogo.cat;
          final lista = [...cat.paradas]
            ..retainWhere((p) => quitarAcentos(p.nombre).contains(quitarAcentos(_q)))
            ..sort((a, b) => a.nombre.compareTo(b.nombre));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(hintText: 'Buscar parada', prefixIcon: Icon(Icons.search), filled: true, fillColor: kSuperficie),
              ),
              const SizedBox(height: 8),
              Text('${lista.length} paradas', style: const TextStyle(color: kTextoSecundario)),
              for (final p in lista)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.signpost_outlined, color: p.activa ? kAcento : kTextoSecundario),
                    title: Text(p.nombre),
                    subtitle: Text('${p.referencia ?? ''}${p.activa ? '' : ' · INACTIVA'}'),
                    trailing: Text('${cat.rutasDeParada(p.id).length} rutas'),
                    onTap: () => abrir(context, ParadaFormPage(vms: widget.vms, parada: p)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ParadaFormPage extends StatefulWidget {
  final AppViewModels vms;
  final Parada? parada;
  const ParadaFormPage({super.key, required this.vms, this.parada});

  @override
  State<ParadaFormPage> createState() => _ParadaFormPageState();
}

class _ParadaFormPageState extends State<ParadaFormPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _referencia = TextEditingController();
  LatLng? _punto;
  bool _activa = true;

  @override
  void initState() {
    super.initState();
    final p = widget.parada;
    if (p != null) {
      _nombre.text = p.nombre;
      _referencia.text = p.referencia ?? '';
      _punto = p.punto;
      _activa = p.activa;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _referencia.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_punto == null) {
      avisar(context, 'Marca la ubicación en el mapa.');
      return;
    }
    if (widget.parada != null && widget.parada!.activa && !_activa) {
      final usos = widget.vms.catalogo.cat.rutasDeParada(widget.parada!.id);
      if (usos.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('¿Desactivar parada?'),
            content: Text('La usan: ${usos.map((u) => '${u.$1.nombre} (${u.$2.sentido.etiqueta})').join(', ')}.\n'
                'Considera publicar un aviso de "parada cerrada".'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Desactivar')),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    try {
      await widget.vms.admin.guardarParada({
        'nombre': _nombre.text.trim(),
        'referencia': _referencia.text.trim().isEmpty ? null : _referencia.text.trim(),
        'latitud': double.parse(_punto!.latitude.toStringAsFixed(6)),
        'longitud': double.parse(_punto!.longitude.toStringAsFixed(6)),
        'activa': _activa,
      }, id: widget.parada?.id);
      await widget.vms.catalogo.refrescar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parada == null ? 'Nueva parada' : 'Editar parada')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CampoTexto(controller: _nombre, etiqueta: 'Nombre', icono: Icons.signpost_outlined, validator: Validadores.requerido, maximo: 100),
            const SizedBox(height: 10),
            CampoTexto(controller: _referencia, etiqueta: 'Referencia (ej. frente a la Parroquia)', icono: Icons.info_outline, maximo: 150),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MapaBase(
                  centro: _punto,
                  zoom: 16,
                  alTocar: (p) => setState(() => _punto = p),
                  capas: [
                    capaRecorridos(widget.vms.catalogo.cat.geos, grosor: 3),
                    if (_punto != null) MarkerLayer(markers: [marcadorIcono(_punto!, Icons.location_on, kAcento)]),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
                  builder: (_) => ElegirEnMapaPage(vms: widget.vms, titulo: 'Ubicación de la parada', inicial: _punto),
                ));
                if (p != null) setState(() => _punto = p);
              },
              icon: const Icon(Icons.fullscreen),
              label: const Text('Elegir en mapa grande'),
            ),
            if (_punto != null)
              Text('${_punto!.latitude.toStringAsFixed(6)}, ${_punto!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: kTextoSecundario)),
            SwitchListTile(
              title: const Text('Activa'),
              value: _activa,
              activeTrackColor: kAcento,
              onChanged: (v) => setState(() => _activa = v),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
              onPressed: _guardar,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
