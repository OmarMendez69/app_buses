import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/app_colors.dart';
import '../../../core/geo.dart';
import '../../../core/idioma.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import 'parada_detalle_page.dart';
import 'ruta_detalle_page.dart';

/// Pestaña "Rutas": lista de rutas y lista/mapa de paradas.
class RutasPage extends StatelessWidget {
  final AppViewModels vms;
  const RutasPage({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tx('Rutas y paradas', 'Routes & stops')),
          bottom: TabBar(
            indicatorColor: kAcento,
            tabs: [Tab(text: tx('Rutas', 'Routes')), Tab(text: tx('Paradas', 'Stops'))],
          ),
        ),
        body: TabBarView(children: [ListaRutas(vms: vms), ListaParadas(vms: vms)]),
      ),
    );
  }
}

class ListaRutas extends StatefulWidget {
  final AppViewModels vms;
  const ListaRutas({super.key, required this.vms});

  @override
  State<ListaRutas> createState() => _ListaRutasState();
}

class _ListaRutasState extends State<ListaRutas> {
  String _q = '';
  bool _soloEnServicio = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.vms.catalogo, widget.vms.favoritos]),
      builder: (context, _) {
        final cat = widget.vms.catalogo.cat;
        final ahora = DateTime.now();
        var rutas = cat.rutasActivas.where((r) => quitarAcentos(r.nombre).contains(quitarAcentos(_q))).toList();
        if (_soloEnServicio) rutas = rutas.where((r) => cat.estadoRuta(r.id, ahora).enServicio).toList();

        return RefreshIndicator(
          onRefresh: widget.vms.catalogo.refrescar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.vms.catalogo.desdeCache && widget.vms.catalogo.error != null)
                BannerSinConexion(actualizado: cat.actualizado),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: tx('Buscar ruta', 'Search route'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: kSuperficie,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              FilterChip(
                label: Text(tx('En servicio ahora', 'Running now')),
                selected: _soloEnServicio,
                onSelected: (v) => setState(() => _soloEnServicio = v),
              ),
              const SizedBox(height: 8),
              if (rutas.isEmpty) EstadoVacio(mensaje: tx('No hay rutas que coincidan', 'No matching routes'), icono: Icons.directions_bus_outlined),
              for (final r in rutas)
                TarjetaRuta(
                  ruta: r,
                  estado: cat.estadoRuta(r.id, ahora),
                  detalle: '\$${r.tarifa.toStringAsFixed(2)}${r.letrero == null ? '' : ' · ${r.letrero}'}',
                  accion: IconButton(
                    icon: Icon(widget.vms.favoritos.sigue(r.id) ? Icons.star : Icons.star_border, color: kAmbar),
                    tooltip: tx('Seguir', 'Follow'),
                    onPressed: () => widget.vms.favoritos.alternar(r.id),
                  ),
                  alTocar: () => abrir(context, RutaDetallePage(vms: widget.vms, idRuta: r.id)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ListaParadas extends StatefulWidget {
  final AppViewModels vms;
  const ListaParadas({super.key, required this.vms});

  @override
  State<ListaParadas> createState() => _ListaParadasState();
}

class _ListaParadasState extends State<ListaParadas> {
  String _q = '';
  bool _mapa = false;
  bool _cercania = false;

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return ListenableBuilder(
      listenable: vms.catalogo,
      builder: (context, _) {
        final cat = vms.catalogo.cat;
        final yo = vms.catalogo.ubicacion;
        var paradas = cat.paradasActivas
            .where((p) => quitarAcentos(p.nombre).contains(quitarAcentos(_q)) || quitarAcentos(p.referencia ?? '').contains(quitarAcentos(_q)))
            .toList();
        if (_cercania && yo != null) {
          paradas.sort((a, b) => distanciaM(yo, a.punto).compareTo(distanciaM(yo, b.punto)));
        }

        final controles = Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: tx('Buscar parada', 'Search stop'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: kSuperficie,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilterChip(
                    label: Text(tx('Más cercanas', 'Nearest')),
                    selected: _cercania,
                    onSelected: (v) async {
                      if (v && yo == null) await vms.catalogo.actualizarUbicacion();
                      setState(() => _cercania = v);
                    },
                  ),
                  const Spacer(),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.list)),
                      ButtonSegment(value: true, icon: Icon(Icons.map_outlined)),
                    ],
                    selected: {_mapa},
                    onSelectionChanged: (s) => setState(() => _mapa = s.first),
                  ),
                ],
              ),
            ],
          ),
        );

        if (_mapa) {
          return Column(
            children: [
              controles,
              Expanded(
                child: MapaBase(
                  centro: yo,
                  capas: [
                    capaRecorridos(cat.geosActivos, grosor: 3),
                    MarkerLayer(markers: [
                      for (final p in paradas)
                        marcadorParada(p, alTocar: () => abrir(context, ParadaDetallePage(vms: vms, idParada: p.id))),
                      if (yo != null) marcadorYo(yo),
                    ]),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            controles,
            Expanded(
              child: paradas.isEmpty
                  ? EstadoVacio(mensaje: tx('No hay paradas que coincidan', 'No matching stops'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: paradas.length,
                      itemBuilder: (context, i) {
                        final p = paradas[i];
                        final rutas = cat.rutasDeParada(p.id).map((e) => e.$1.nombre).toSet();
                        final distancia = yo == null ? '' : ' · ${distanciaM(yo, p.punto).round()} m';
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.signpost_outlined, color: kAcento),
                            title: Text(p.nombre),
                            subtitle: Text('${rutas.isEmpty ? tx('Sin rutas', 'No routes') : rutas.join(', ')}$distancia'),
                            onTap: () => abrir(context, ParadaDetallePage(vms: vms, idParada: p.id)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
