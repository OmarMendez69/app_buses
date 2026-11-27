import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_colors.dart';
import '../../../core/config.dart';
import '../../../core/idioma.dart';
import '../../../domain/catalogo.dart';
import '../../../core/geo.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import 'ruta_detalle_page.dart';

/// Tocas cualquier calle (o usas tu ubicación) y ves qué rutas pasan a menos de 100 m.
class QuePasaAquiPage extends StatefulWidget {
  final AppViewModels vms;
  const QuePasaAquiPage({super.key, required this.vms});

  @override
  State<QuePasaAquiPage> createState() => _QuePasaAquiPageState();
}

class _QuePasaAquiPageState extends State<QuePasaAquiPage> {
  LatLng? _punto;
  final _mapa = MapController();

  @override
  void initState() {
    super.initState();
    _punto = widget.vms.catalogo.ubicacion;
  }

  Future<void> _aqui() async {
    final u = await widget.vms.catalogo.actualizarUbicacion();
    if (u == null) {
      if (mounted) avisar(context, tx('No pude obtener tu ubicación.', "Couldn't get your location."));
      return;
    }
    setState(() => _punto = u);
    _mapa.move(u, 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final cerca = _punto == null ? <(RecorridoGeo, Proyeccion)>[] : cat.recorridosCerca(_punto!, Config.radioQuePasaAqui);
    final ahora = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(tx('¿Qué rutas pasan por aquí?', 'Which routes pass here?'))),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(children: [
              MapaBase(
                controller: _mapa,
                centro: _punto,
                zoom: 16,
                alTocar: (p) => setState(() => _punto = p),
                capas: [
                  capaRecorridos(cat.geosActivos, grosor: 4, resaltadas: cerca.map((c) => c.$1.ruta.id).toSet()),
                  if (_punto != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _punto!,
                        radius: Config.radioQuePasaAqui,
                        useRadiusInMeter: true,
                        color: kAcento.withValues(alpha: 0.15),
                        borderColor: kAcento,
                        borderStrokeWidth: 2,
                      ),
                    ]),
                  if (_punto != null) MarkerLayer(markers: [marcadorIcono(_punto!, Icons.location_on, kAcento)]),
                ],
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: 'aqui',
                  backgroundColor: kSuperficie,
                  onPressed: _aqui,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: _punto == null
                ? EstadoVacio(mensaje: tx('Toca una calle del mapa', 'Tap a street on the map'), icono: Icons.touch_app_outlined)
                : cerca.isEmpty
                    ? EstadoVacio(mensaje: tx('Ninguna ruta pasa a menos de 100 m de este punto.', 'No route passes within 100 m of this point.'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final (g, pr) in cerca)
                            TarjetaRuta(
                              ruta: g.ruta,
                              estado: cat.estadoRecorrido(g.recorrido.id, ahora),
                              detalle: tx('${g.recorrido.sentido.etiqueta} · a ${pr.distancia.round()} m · hacia ${g.paradas.isEmpty ? '' : g.paradas.last.$1.nombre}',
                                  '${g.recorrido.sentido.etiqueta} · ${pr.distancia.round()} m away · towards ${g.paradas.isEmpty ? '' : g.paradas.last.$1.nombre}'),
                              alTocar: () => abrir(context, RutaDetallePage(vms: widget.vms, idRuta: g.ruta.id)),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
