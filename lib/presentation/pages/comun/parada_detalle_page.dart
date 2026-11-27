import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../domain/entities/viaje.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import 'planificador_page.dart';
import 'ruta_detalle_page.dart';

class ParadaDetallePage extends StatefulWidget {
  final AppViewModels vms;
  final int idParada;
  const ParadaDetallePage({super.key, required this.vms, required this.idParada});

  @override
  State<ParadaDetallePage> createState() => _ParadaDetallePageState();
}

class _ParadaDetallePageState extends State<ParadaDetallePage> {
  List<LatLng>? _caminata;
  String? _infoCaminata;
  bool _calculando = false;

  Future<void> _comoLlegar() async {
    final cat = widget.vms.catalogo.cat;
    final parada = cat.paradaPorId[widget.idParada]!;
    setState(() => _calculando = true);
    final yo = await widget.vms.catalogo.actualizarUbicacion();
    if (yo == null) {
      setState(() => _calculando = false);
      if (mounted) avisar(context, tx('Activa tu ubicación para calcular la caminata.', 'Turn on location to calculate the walk.'));
      return;
    }
    final r = await widget.vms.externos.rutaAPie(yo, parada.punto);
    if (!mounted) return;
    setState(() {
      _calculando = false;
      if (r == null) {
        _caminata = [yo, parada.punto];
        _infoCaminata = tx('Sin internet: se muestra la línea recta.', 'Offline: showing a straight line.');
      } else {
        _caminata = r.$3;
        _infoCaminata = tx('${r.$1.round()} m · ${r.$2} min caminando', '${r.$1.round()} m · ${r.$2} min walking');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    final cat = vms.catalogo.cat;
    final parada = cat.paradaPorId[widget.idParada];
    if (parada == null) {
      return Scaffold(appBar: AppBar(), body: EstadoVacio(mensaje: tx('Parada no disponible', 'Stop not available')));
    }
    final ahora = DateTime.now();
    final rutas = cat.rutasDeParada(parada.id);
    final avisos = cat.avisosVigentes(ahora).where((a) => a.paradasAfectadas.contains(parada.id)).toList();
    final yo = vms.catalogo.ubicacion;

    return Scaffold(
      appBar: AppBar(title: Text(parada.nombre)),
      body: ListView(
        children: [
          SizedBox(
            height: 240,
            child: MapaBase(
              centro: parada.punto,
              zoom: 16,
              capas: [
                capaRecorridos(rutas.map((r) => cat.geos.firstWhere((g) => g.recorrido.id == r.$2.id)), grosor: 4),
                if (_caminata != null)
                  PolylineLayer(polylines: [Polyline(points: _caminata!, color: Colors.lightBlueAccent, strokeWidth: 4, pattern: StrokePattern.dotted())]),
                MarkerLayer(markers: [marcadorParada(parada, tam: 22), if (yo != null && _caminata != null) marcadorYo(yo)]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parada.referencia != null) Text(parada.referencia!, style: const TextStyle(color: kTextoSecundario)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _calculando ? null : _comoLlegar,
                      icon: _calculando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.directions_walk),
                      label: Text(tx('Cómo llegar caminando', 'Walking directions')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kAcento),
                      onPressed: () => abrir(context, PlanificadorPage(vms: vms, destinoInicial: PuntoNombrado(parada.nombre, parada.punto))),
                      icon: const Icon(Icons.alt_route),
                      label: Text(tx('Planear viaje', 'Plan trip')),
                    ),
                  ),
                ]),
                if (_infoCaminata != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_infoCaminata!)),
                for (final a in avisos) TarjetaAviso(aviso: a, ruta: cat.rutaPorId[a.idRuta]),
                TituloSeccion(tx('Rutas que pasan', 'Routes that stop here')),
                if (rutas.isEmpty) Text(tx('Ninguna ruta registrada pasa por aquí.', 'No registered route stops here.')),
                for (final (ruta, rec) in rutas)
                  TarjetaRuta(
                    ruta: ruta,
                    estado: cat.estadoRecorrido(rec.id, ahora),
                    detalle: rec.sentido.etiqueta,
                    alTocar: () => abrir(context, RutaDetallePage(vms: vms, idRuta: ruta.id)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
