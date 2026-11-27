import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_colors.dart';
import '../../../core/config.dart';
import '../../../core/geo.dart';
import '../../../core/idioma.dart';
import '../../../domain/catalogo.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import '../../widgets/reporte_rapido.dart';
import '../../widgets/selector_punto.dart';
import '../comun/hora_pico_page.dart';
import '../comun/parada_detalle_page.dart';
import '../comun/planificador_page.dart';
import '../comun/que_pasa_aqui_page.dart';
import '../comun/ruta_detalle_page.dart';
import '../visitante/visitante_shell.dart';

/// Dashboard del Usuario: mapa real, "¿A dónde vas?", rutas cercanas y rutas que sigues.
class InicioMapaPage extends StatefulWidget {
  final AppViewModels vms;
  const InicioMapaPage({super.key, required this.vms});

  @override
  State<InicioMapaPage> createState() => _InicioMapaPageState();
}

class _InicioMapaPageState extends State<InicioMapaPage> {
  final _mapa = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.vms.catalogo.ubicacion == null) _ubicar(mover: false);
  }

  Future<void> _ubicar({bool mover = true}) async {
    final u = await widget.vms.catalogo.actualizarUbicacion();
    if (u != null && mover && mounted) _mapa.move(u, 16);
  }

  Future<void> _aDonde() async {
    final destino = await elegirPunto(context, widget.vms, titulo: tx('¿A dónde vas?', 'Where to?'));
    if (destino != null && mounted) abrir(context, PlanificadorPage(vms: widget.vms, destinoInicial: destino));
  }

  /// Reporte rápido: si estás cerca de una ruta, la deja elegida (se puede cambiar en la hoja).
  Future<void> _reportar() async {
    final vms = widget.vms;
    final yo = vms.catalogo.ubicacion;
    int? idRuta;
    if (yo != null) {
      final cerca = vms.catalogo.cat.recorridosCerca(yo, Config.radioCercania);
      if (cerca.isNotEmpty) idRuta = cerca.first.$1.ruta.id;
    }
    await mostrarReporteRapido(context, vms, idRutaSugerida: idRuta);
  }

  /// Rutas a menos de 500 m: la más cercana de cada ruta, con su parada de referencia.
  List<(RecorridoGeo, Proyeccion, Parada?, double)> _cercanas(Catalogo cat, LatLng yo) {
    final porRuta = <int, (RecorridoGeo, Proyeccion)>{};
    for (final (g, pr) in cat.recorridosCerca(yo, Config.radioCercania)) {
      final previo = porRuta[g.ruta.id];
      if (previo == null || pr.distancia < previo.$2.distancia) porRuta[g.ruta.id] = (g, pr);
    }
    final res = <(RecorridoGeo, Proyeccion, Parada?, double)>[];
    for (final (g, pr) in porRuta.values) {
      Parada? cercana;
      var mejor = double.infinity;
      for (final p in g.paradas) {
        final d = distanciaM(yo, p.$1.punto);
        if (d < mejor) {
          mejor = d;
          cercana = p.$1;
        }
      }
      res.add((g, pr, cercana, mejor));
    }
    res.sort((a, b) => a.$2.distancia.compareTo(b.$2.distancia));
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'publicar_inicio',
        backgroundColor: kAcento,
        onPressed: _reportar,
        icon: const Icon(Icons.campaign_outlined),
        label: Text(tx('Reportar', 'Report')),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([vms.catalogo, vms.favoritos]),
        builder: (context, _) {
          final cat = vms.catalogo.cat;
          final yo = vms.catalogo.ubicacion;
          final ahora = DateTime.now();
          final paradasCerca = yo == null ? <(Parada, double)>[] : cat.paradasCerca(yo, Config.radioCercania);
          final cercanas = yo == null ? <(RecorridoGeo, Proyeccion, Parada?, double)>[] : _cercanas(cat, yo);
          final favoritas = cat.rutasActivas.where((r) => vms.favoritos.sigue(r.id)).toList();

          return Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.42,
                child: Stack(children: [
                  MapaBase(
                    controller: _mapa,
                    centro: yo,
                    zoom: 15.5,
                    capas: [
                      capaRecorridos(cat.geosActivos, grosor: 4, resaltadas: cercanas.map((c) => c.$1.ruta.id).toSet()),
                      MarkerLayer(markers: [
                        for (final (p, _) in paradasCerca)
                          marcadorParada(p, tam: 14, alTocar: () => abrir(context, ParadaDetallePage(vms: vms, idParada: p.id))),
                        if (yo != null) marcadorYo(yo),
                      ]),
                    ],
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 12,
                    right: 12,
                    child: Row(children: [
                      Expanded(child: BuscadorADonde(alTocar: _aDonde)),
                      const SizedBox(width: 8),
                      Material(color: kSuperficie, shape: const CircleBorder(), child: Campana(vms: vms)),
                    ]),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'ubicar',
                      backgroundColor: kSuperficie,
                      onPressed: _ubicar,
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vms.catalogo.refrescar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    children: [
                      if (vms.catalogo.desdeCache && vms.catalogo.error != null) BannerSinConexion(actualizado: cat.actualizado),
                      TituloSeccion(
                        tx('Rutas cercanas', 'Nearby routes'),
                        accion: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: tx('¿Qué rutas pasan por aquí?', 'Which routes pass here?'),
                            onPressed: () => abrir(context, QuePasaAquiPage(vms: vms)),
                            icon: const Icon(Icons.near_me_outlined, color: kAcento),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => abrir(context, HoraPicoPage(vms: vms)),
                            icon: const Icon(Icons.schedule, size: 16),
                            label: Text(tx('Hora pico', 'Peak hours')),
                            style: OutlinedButton.styleFrom(foregroundColor: kAcento, side: const BorderSide(color: kAcento)),
                          ),
                        ]),
                      ),
                      if (yo == null)
                        ListTile(
                          leading: const Icon(Icons.location_off_outlined),
                          title: Text(tx('Activa tu ubicación para ver rutas cercanas', 'Turn on location to see nearby routes')),
                          onTap: _ubicar,
                        )
                      else if (cercanas.isEmpty)
                        Text(tx('Ninguna ruta pasa a menos de 500 m.', 'No route passes within 500 m.'),
                            style: const TextStyle(color: kTextoSecundario)),
                      for (final (g, pr, parada, dParada) in cercanas)
                        TarjetaRuta(
                          ruta: g.ruta,
                          estado: cat.estadoRecorrido(g.recorrido.id, ahora),
                          detalle: parada != null && dParada <= Config.radioCercania
                              ? '${parada.nombre} · ${dParada.round()} m'
                              : tx('Pasa a ${pr.distancia.round()} m (hazle la mano)', 'Passes ${pr.distancia.round()} m away (wave it down)'),
                          alTocar: () => abrir(context, RutaDetallePage(vms: vms, idRuta: g.ruta.id)),
                        ),
                      if (favoritas.isNotEmpty) TituloSeccion(tx('Rutas que sigues', 'Routes you follow')),
                      for (final r in favoritas)
                        TarjetaRuta(
                          ruta: r,
                          estado: cat.estadoRuta(r.id, ahora),
                          alTocar: () => abrir(context, RutaDetallePage(vms: vms, idRuta: r.id)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
