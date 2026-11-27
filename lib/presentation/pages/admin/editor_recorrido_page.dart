import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_colors.dart';
import '../../../core/config.dart';
import '../../../core/geo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';

/// Lee los puntos de un archivo GPX (grabado con OsmAnd, OpenTracks, etc.).
/// Deja un punto cada 15 m como mínimo para no guardar miles de puntos.
List<LatLng> leerGpx(String xml) {
  final etiquetas = RegExp(r'<(trkpt|rtept)\b[^>]*>').allMatches(xml);
  final lat = RegExp(r'lat="([-0-9.]+)"');
  final lon = RegExp(r'lon="([-0-9.]+)"');
  final puntos = <LatLng>[];
  for (final m in etiquetas) {
    final t = m.group(0)!;
    final la = lat.firstMatch(t), lo = lon.firstMatch(t);
    if (la == null || lo == null) continue;
    final p = LatLng(double.parse(la.group(1)!), double.parse(lo.group(1)!));
    if (puntos.isEmpty || distanciaM(puntos.last, p) >= 15) puntos.add(p);
  }
  return puntos;
}

enum _Modo { trazar, paradas }

class EditorRecorridoPage extends StatefulWidget {
  final AppViewModels vms;
  final int idRecorrido;
  const EditorRecorridoPage({super.key, required this.vms, required this.idRecorrido});

  @override
  State<EditorRecorridoPage> createState() => _EditorRecorridoPageState();
}

class _Seleccion {
  final int idParada;
  final TextEditingController minutos;
  _Seleccion(this.idParada, int? min) : minutos = TextEditingController(text: min?.toString() ?? '');
}

class _EditorRecorridoPageState extends State<EditorRecorridoPage> {
  List<LatLng> _trazado = [];
  final List<_Seleccion> _paradas = [];
  _Modo _modo = _Modo.trazar;
  bool _guardando = false;
  Recorrido? _rec;

  @override
  void initState() {
    super.initState();
    final cat = widget.vms.catalogo.cat;
    _rec = cat.recorridos.where((r) => r.id == widget.idRecorrido).firstOrNull;
    if (_rec != null) {
      _trazado = [..._rec!.trazado];
      for (final p in _rec!.paradas) {
        _paradas.add(_Seleccion(p.idParada, p.minDesdeInicio));
      }
    }
  }

  @override
  void dispose() {
    for (final s in _paradas) {
      s.minutos.dispose();
    }
    super.dispose();
  }

  void _tocar(LatLng p) {
    if (_modo == _Modo.trazar) {
      setState(() => _trazado.add(p));
      return;
    }
    // Modo paradas: toca una parada existente (a menos de 40 m) para agregarla o quitarla.
    final cerca = widget.vms.catalogo.cat.paradasCerca(p, 40);
    if (cerca.isEmpty) {
      avisar(context, 'Toca sobre una parada, o mantén presionado para crear una nueva aquí.');
      return;
    }
    final id = cerca.first.$1.id;
    setState(() {
      final i = _paradas.indexWhere((s) => s.idParada == id);
      if (i >= 0) {
        _paradas.removeAt(i).minutos.dispose();
      } else {
        _paradas.add(_Seleccion(id, null));
      }
    });
  }

  Future<void> _crearParada(LatLng p) async {
    final nombre = TextEditingController();
    final referencia = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nueva parada aquí'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombre, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: referencia, decoration: const InputDecoration(labelText: 'Referencia (ej. frente a la farmacia)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Crear')),
        ],
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    try {
      await widget.vms.admin.guardarParada({
        'nombre': nombre.text.trim(),
        'referencia': referencia.text.trim().isEmpty ? null : referencia.text.trim(),
        'latitud': double.parse(p.latitude.toStringAsFixed(6)),
        'longitud': double.parse(p.longitude.toStringAsFixed(6)),
      });
      await widget.vms.catalogo.refrescar();
      final nueva = widget.vms.catalogo.cat.paradasCerca(p, 5);
      if (nueva.isNotEmpty) setState(() => _paradas.add(_Seleccion(nueva.first.$1.id, null)));
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _importarGpx() async {
    const gpx = XTypeGroup(
      label: 'GPX',
      extensions: ['gpx'],
      mimeTypes: ['application/gpx+xml', 'application/xml', 'text/xml', 'application/octet-stream'],
      uniformTypeIdentifiers: ['public.xml'],
    );
    final archivo = await openFile(acceptedTypeGroups: const [gpx]);
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    final puntos = leerGpx(utf8.decode(bytes, allowMalformed: true));
    if (puntos.length < 2) {
      if (mounted) avisar(context, 'El archivo no tiene una traza válida.');
      return;
    }
    setState(() => _trazado = puntos);
    if (mounted) avisar(context, 'Se importaron ${puntos.length} puntos.');
  }

  void _ordenarPorTrazado() {
    if (_trazado.length < 2) return;
    final linea = Linea(_trazado);
    final cat = widget.vms.catalogo.cat;
    setState(() {
      _paradas.sort((a, b) {
        final pa = cat.paradaPorId[a.idParada], pb = cat.paradaPorId[b.idParada];
        if (pa == null || pb == null) return 0;
        return linea.proyectar(pa.punto).avance.compareTo(linea.proyectar(pb.punto).avance);
      });
    });
  }

  Future<void> _guardar() async {
    if (_trazado.length < 2) {
      avisar(context, 'El trazado necesita al menos 2 puntos.');
      return;
    }
    final lista = <(int, int?)>[];
    for (final s in _paradas) {
      final t = s.minutos.text.trim();
      final m = t.isEmpty ? null : int.tryParse(t);
      if (t.isNotEmpty && m == null) {
        avisar(context, 'Revisa los minutos: solo números enteros.');
        return;
      }
      lista.add((s.idParada, m));
    }
    setState(() => _guardando = true);
    try {
      await widget.vms.admin.guardarRecorrido(widget.idRecorrido, _trazado, lista);
      await widget.vms.catalogo.refrescar();
      if (mounted) {
        avisar(context, 'Recorrido guardado. Se avisó a quien sigue la ruta (si está activa).');
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
    final ruta = _rec == null ? null : cat.rutaPorId[_rec!.idRuta];
    final color = ruta == null ? kAcento : colorDesdeHex(ruta.color);
    final seleccionadas = {for (var i = 0; i < _paradas.length; i++) _paradas[i].idParada: i + 1};
    final largo = Linea(_trazado).largo;

    return Scaffold(
      appBar: AppBar(
        title: Text('${ruta?.nombre ?? 'Recorrido'} · ${_rec?.sentido.etiqueta ?? ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.save), tooltip: 'Guardar', onPressed: _guardando ? null : _guardar),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _trazado.isNotEmpty ? _trazado.first : const LatLng(Config.centroLat, Config.centroLng),
                initialZoom: 15,
                onTap: (_, p) => _tocar(p),
                onLongPress: (_, p) => _modo == _Modo.paradas ? _crearParada(p) : null,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: Config.userAgent,
                  tileBuilder: darkModeTileBuilder,
                ),
                PolylineLayer(polylines: [Polyline(points: _trazado, color: color, strokeWidth: 5)]),
                if (_modo == _Modo.trazar)
                  CircleLayer(circles: [
                    for (final p in _trazado) CircleMarker(point: p, radius: 3, color: Colors.white),
                  ]),
                MarkerLayer(markers: [
                  for (final p in cat.paradas)
                    Marker(
                      point: p.punto,
                      width: 30,
                      height: 30,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: seleccionadas.containsKey(p.id) ? kAcento : Colors.grey.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(seleccionadas[p.id]?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                ]),
                const SimpleAttributionWidget(source: Text('OpenStreetMap')),
              ],
            ),
          ),
          Container(
            color: kSuperficie,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(children: [
              SegmentedButton<_Modo>(
                segments: const [
                  ButtonSegment(value: _Modo.trazar, icon: Icon(Icons.timeline), label: Text('Trazar')),
                  ButtonSegment(value: _Modo.paradas, icon: Icon(Icons.signpost_outlined), label: Text('Paradas')),
                ],
                selected: {_modo},
                onSelectionChanged: (s) => setState(() => _modo = s.first),
              ),
              Text(
                _modo == _Modo.trazar
                    ? 'Toca el mapa en orden para dibujar el recorrido. ${_trazado.length} puntos · ${(largo / 1000).toStringAsFixed(2)} km'
                    : 'Toca una parada para agregarla/quitarla. Mantén presionado para crear una nueva.',
                style: const TextStyle(fontSize: 12, color: kTextoSecundario),
                textAlign: TextAlign.center,
              ),
              Wrap(spacing: 4, alignment: WrapAlignment.center, children: [
                if (_modo == _Modo.trazar) ...[
                  TextButton.icon(
                    onPressed: _trazado.isEmpty ? null : () => setState(() => _trazado.removeLast()),
                    icon: const Icon(Icons.undo),
                    label: const Text('Deshacer'),
                  ),
                  TextButton.icon(
                    onPressed: _trazado.isEmpty ? null : () => setState(() => _trazado = []),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar'),
                  ),
                  TextButton.icon(onPressed: _importarGpx, icon: const Icon(Icons.upload_file), label: const Text('Importar GPX')),
                ] else
                  TextButton.icon(
                    onPressed: _ordenarPorTrazado,
                    icon: const Icon(Icons.sort),
                    label: const Text('Ordenar según el trazado'),
                  ),
              ]),
            ]),
          ),
          Expanded(
            flex: 2,
            child: _paradas.isEmpty
                ? const Center(child: Text('Sin paradas. Cambia a modo "Paradas" para agregarlas.', style: TextStyle(color: kTextoSecundario)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _paradas.length,
                    // onReorderItem ya entrega la posición final (no hay que restar 1).
                    onReorderItem: (a, b) => setState(() {
                      _paradas.insert(b, _paradas.removeAt(a));
                    }),
                    itemBuilder: (context, i) {
                      final s = _paradas[i];
                      final p = cat.paradaPorId[s.idParada];
                      return ListTile(
                        key: ValueKey(s.idParada),
                        dense: true,
                        leading: CircleAvatar(radius: 14, backgroundColor: color, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))),
                        title: Text(p?.nombre ?? 'Parada ${s.idParada}'),
                        subtitle: Text(i == 0 ? 'Terminal de salida (0 min)' : 'Minutos desde la terminal (medidos)'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 56,
                            child: TextField(
                              controller: s.minutos,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(hintText: 'min', isDense: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _paradas.removeAt(i).minutos.dispose()),
                          ),
                          const Icon(Icons.drag_handle),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
