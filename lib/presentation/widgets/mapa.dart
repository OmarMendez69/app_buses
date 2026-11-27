import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_colors.dart';
import '../../core/config.dart';
import '../../domain/catalogo.dart';
import '../../domain/entities/transporte.dart';

/// Mapa base con OpenStreetMap (en tono oscuro) y su atribución.
class MapaBase extends StatelessWidget {
  final LatLng? centro;
  final double zoom;
  final List<Widget> capas;
  final void Function(LatLng)? alTocar;
  final MapController? controller;

  const MapaBase({super.key, this.centro, this.zoom = 14.5, this.capas = const [], this.alTocar, this.controller});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: centro ?? const LatLng(Config.centroLat, Config.centroLng),
        initialZoom: zoom,
        minZoom: 11,
        maxZoom: 19,
        onTap: alTocar == null ? null : (_, p) => alTocar!(p),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: Config.userAgent,
          tileBuilder: darkModeTileBuilder,
        ),
        ...capas,
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}

/// Líneas de los recorridos, cada una con el color de su ruta.
PolylineLayer capaRecorridos(Iterable<RecorridoGeo> geos, {double grosor = 5, Set<int> resaltadas = const {}}) {
  return PolylineLayer(
    polylines: [
      for (final g in geos)
        if (g.usable)
          Polyline(
            points: g.linea.puntos,
            color: colorDesdeHex(g.ruta.color).withValues(alpha: resaltadas.isEmpty || resaltadas.contains(g.ruta.id) ? 0.95 : 0.3),
            strokeWidth: resaltadas.contains(g.ruta.id) ? grosor + 2 : grosor,
          ),
    ],
  );
}

Marker marcadorParada(Parada p, {VoidCallback? alTocar, Color color = Colors.white, double tam = 18}) => Marker(
      point: p.punto,
      width: tam + 10,
      height: tam + 10,
      child: GestureDetector(
        onTap: alTocar,
        child: Center(
          child: Container(
            width: tam,
            height: tam,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: kAcento, width: 3),
            ),
          ),
        ),
      ),
    );

Marker marcadorYo(LatLng p) => Marker(
      point: p,
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 4)],
        ),
      ),
    );

Marker marcadorIcono(LatLng p, IconData icono, Color color) => Marker(
      point: p,
      width: 36,
      height: 36,
      alignment: Alignment.topCenter,
      child: Icon(icono, color: color, size: 36),
    );
