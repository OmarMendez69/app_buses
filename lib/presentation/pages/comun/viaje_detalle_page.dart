import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../domain/entities/viaje.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import 'en_viaje_page.dart';

/// Pasos del viaje en orden, con el trayecto en el mapa.
class ViajeDetallePage extends StatefulWidget {
  final AppViewModels vms;
  final OpcionViaje opcion;
  final PuntoNombrado origen;
  final PuntoNombrado destino;

  const ViajeDetallePage({super.key, required this.vms, required this.opcion, required this.origen, required this.destino});

  @override
  State<ViajeDetallePage> createState() => _ViajeDetallePageState();
}

class _ViajeDetallePageState extends State<ViajeDetallePage> {
  /// Caminatas reales por calles (OpenRouteService), por índice de tramo.
  final Map<int, (double, int, List<LatLng>)> _caminatas = {};

  @override
  void initState() {
    super.initState();
    _cargarCaminatas();
  }

  Future<void> _cargarCaminatas() async {
    final tramos = widget.opcion.tramos;
    for (var i = 0; i < tramos.length; i++) {
      final t = tramos[i];
      if (t.tipo != TipoTramo.caminar || t.metros < 60) continue;
      final r = await widget.vms.externos.rutaAPie(t.desde, t.hasta);
      if (r != null && mounted) setState(() => _caminatas[i] = r);
    }
  }

  String _textoCompartir() {
    final o = widget.opcion;
    final llegada = DateTime.now();
    final min = llegada.add(Duration(minutes: o.minMinutos));
    final max = llegada.add(Duration(minutes: o.maxMinutos));
    final rango = '${textoHora(minutosDelDia(min))} y ${textoHora(minutosDelDia(max))}';
    if (o.soloCaminando) {
      return tx('Voy caminando a ${widget.destino.nombre}, llego entre $rango.',
          "I'm walking to ${widget.destino.nombre}, arriving between ${textoHora(minutosDelDia(min))} and ${textoHora(minutosDelDia(max))}.");
    }
    return tx('Voy en ${o.resumen} hacia ${widget.destino.nombre}, llego entre $rango.',
        "I'm taking ${o.resumen} to ${widget.destino.nombre}, arriving between ${textoHora(minutosDelDia(min))} and ${textoHora(minutosDelDia(max))}.");
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.opcion;
    final buses = o.enCamion;

    final lineas = <Polyline>[];
    final todos = <LatLng>[];
    for (var i = 0; i < o.tramos.length; i++) {
      final t = o.tramos[i];
      if (t.tipo == TipoTramo.camion) {
        final g = widget.vms.catalogo.cat.geos.where((g) => g.recorrido.id == t.recorrido!.id).firstOrNull;
        final puntos = g == null ? [t.desde, t.hasta] : g.linea.tramo(t.avanceSube, t.avanceBaja);
        if (puntos.length >= 2) lineas.add(Polyline(points: puntos, color: colorDesdeHex(t.ruta!.color), strokeWidth: 6));
        todos.addAll(puntos);
      } else {
        final puntos = _caminatas[i]?.$3 ?? [t.desde, t.hasta];
        if (puntos.length >= 2) lineas.add(Polyline(points: puntos, color: Colors.lightBlueAccent, strokeWidth: 4, pattern: StrokePattern.dotted()));
        todos.addAll(puntos);
      }
    }
    final centro = todos.isEmpty
        ? null
        : LatLng(todos.map((p) => p.latitude).reduce((a, b) => a + b) / todos.length,
            todos.map((p) => p.longitude).reduce((a, b) => a + b) / todos.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(o.resumen),
        actions: [
          IconButton(
            tooltip: tx('Compartir mi viaje', 'Share my trip'),
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(_textoCompartir()),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 280,
            child: MapaBase(
              centro: centro,
              zoom: 14,
              capas: [
                if (lineas.isNotEmpty) PolylineLayer(polylines: lineas),
                MarkerLayer(markers: [
                  marcadorIcono(widget.origen.punto, Icons.trip_origin, Colors.blueAccent),
                  marcadorIcono(widget.destino.punto, Icons.location_on, kAcento),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rangoMinutos(o.minMinutos, o.maxMinutos), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                Text(tx('Tiempo total aproximado', 'Approximate total time'), style: const TextStyle(color: kTextoSecundario)),
                for (final a in o.avisosVigentes) TarjetaAviso(aviso: a, ruta: widget.vms.catalogo.cat.rutaPorId[a.idRuta]),
                for (final d in o.avisosDemanda)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.groups_outlined, size: 18, color: kAmbar),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
                TituloSeccion(tx('Pasos', 'Steps')),
                for (var i = 0; i < o.tramos.length; i++) _paso(i, o.tramos[i]),
                const SizedBox(height: 16),
                if (buses.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
                    onPressed: () => abrir(context, EnViajePage(vms: widget.vms, opcion: o, destino: widget.destino, textoCompartir: _textoCompartir())),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(tx('Iniciar viaje y avisarme al llegar', 'Start trip and alert me')),
                  ),
                const SizedBox(height: 8),
                for (final b in buses)
                  OutlinedButton.icon(
                    onPressed: () => widget.vms.favoritos.alternar(b.ruta!.id).then((_) {
                      if (context.mounted) setState(() {});
                    }),
                    icon: Icon(widget.vms.favoritos.sigue(b.ruta!.id) ? Icons.star : Icons.star_border, color: kAmbar),
                    label: Text(widget.vms.favoritos.sigue(b.ruta!.id)
                        ? tx('Siguiendo ${b.ruta!.nombre}', 'Following ${b.ruta!.nombre}')
                        : tx('Seguir ${b.ruta!.nombre} para recibir avisos', 'Follow ${b.ruta!.nombre} for notices')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paso(int i, Tramo t) {
    if (t.tipo == TipoTramo.caminar) {
      final real = _caminatas[i];
      final metros = real?.$1 ?? t.metros;
      final minutos = real?.$2 ?? t.minutos;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: kSuperficie, child: Icon(Icons.directions_walk, color: Colors.lightBlueAccent)),
        title: Text(tx('Camina a ${t.hastaNombre}', 'Walk to ${t.hastaNombre}')),
        subtitle: Text('${metros.round()} m · $minutos min${real == null ? tx(' (aprox.)', ' (approx.)') : ''}'),
      );
    }
    final ruta = t.ruta!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: colorDesdeHex(ruta.color), child: const Icon(Icons.directions_bus, color: Colors.white)),
      title: Text(tx('Toma la ${ruta.nombre} (${t.recorrido!.sentido.etiqueta.toLowerCase()})', 'Take ${ruta.nombre} (${t.recorrido!.sentido.etiqueta.toLowerCase()})')),
      subtitle: Text([
        tx('Sube en: ${t.desdeNombre}', 'Board at: ${t.desdeNombre}'),
        tx('Bájate en: ${t.hastaNombre}', 'Get off at: ${t.hastaNombre}'),
        if (ruta.letrero != null) tx('Letrero: ${ruta.letrero}', 'Sign: ${ruta.letrero}'),
        tx('${t.paradasIntermedias} paradas · ${t.minutos} min${t.minutosEstimados ? ' (estimado)' : ''}',
            '${t.paradasIntermedias} stops · ${t.minutos} min${t.minutosEstimados ? ' (estimated)' : ''}'),
        if (t.frecuenciaMax != null) tx('Pasa cada ${rangoMinutos(t.frecuenciaMin!, t.frecuenciaMax!)}', 'Every ${rangoMinutos(t.frecuenciaMin!, t.frecuenciaMax!)}'),
        tx('Pasaje: \$${ruta.tarifa.toStringAsFixed(2)}', 'Fare: \$${ruta.tarifa.toStringAsFixed(2)}'),
      ].join('\n')),
      isThreeLine: true,
    );
  }
}
