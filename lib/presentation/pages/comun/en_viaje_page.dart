import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../domain/entities/viaje.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/mapa.dart';

/// Viaje en curso: tu posición sobre el recorrido (GPS de tu teléfono),
/// cuántas paradas faltan y alarma unos 300 m antes de bajar.
class EnViajePage extends StatefulWidget {
  final AppViewModels vms;
  final OpcionViaje opcion;
  final PuntoNombrado destino;
  final String textoCompartir;

  const EnViajePage({super.key, required this.vms, required this.opcion, required this.destino, required this.textoCompartir});

  @override
  State<EnViajePage> createState() => _EnViajePageState();
}

class _EnViajePageState extends State<EnViajePage> {
  int _tramo = 0;
  final _mapa = MapController();

  List<Tramo> get _buses => widget.opcion.enCamion;

  @override
  void initState() {
    super.initState();
    _iniciarTramo();
  }

  Future<void> _iniciarTramo() async {
    final t = _buses[_tramo];
    final geo = widget.vms.catalogo.cat.geos.where((g) => g.recorrido.id == t.recorrido!.id).firstOrNull;
    if (geo == null) return;
    await widget.vms.seguimiento.iniciar(geo, t.avanceSube, t.avanceBaja, t.hastaNombre);
  }

  Future<void> _terminar() async {
    await widget.vms.seguimiento.detener();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.vms.seguimiento;
    final t = _buses[_tramo];

    return PopScope(
      onPopInvokedWithResult: (_, __) => s.detener(),
      child: Scaffold(
        appBar: AppBar(title: Text(tx('Viaje en curso', 'Trip in progress'))),
        body: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final e = s.estado;
            final geo = s.geo;
            return Column(
              children: [
                Expanded(
                  child: MapaBase(
                    controller: _mapa,
                    centro: e?.posicion ?? t.desde,
                    zoom: 16,
                    capas: [
                      if (geo != null && geo.linea.tramo(t.avanceSube, t.avanceBaja).length >= 2)
                        PolylineLayer(polylines: [
                          Polyline(points: geo.linea.tramo(t.avanceSube, t.avanceBaja), color: colorDesdeHex(t.ruta!.color), strokeWidth: 7),
                        ]),
                      MarkerLayer(markers: [
                        marcadorIcono(t.hasta, Icons.flag, kAcento),
                        if (e != null) marcadorYo(e.posicion),
                      ]),
                    ],
                  ),
                ),
                Container(
                  color: kSuperficie,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.ruta!.nombre, style: TextStyle(color: colorDesdeHex(t.ruta!.color), fontWeight: FontWeight.bold)),
                      Text(tx('Bájate en: ${t.hastaNombre}', 'Get off at: ${t.hastaNombre}'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (s.error != null)
                        Text(s.error!, style: const TextStyle(color: Colors.redAccent))
                      else if (e == null)
                        Text(tx('Buscando tu ubicación…', 'Finding your location…'), style: const TextStyle(color: kTextoSecundario))
                      else if (e.llegando)
                        Text(tx('¡Prepárate! Tu bajada está a menos de 300 m.', 'Get ready! Your stop is less than 300 m away.'),
                            style: const TextStyle(color: kAmbar, fontSize: 16, fontWeight: FontWeight.bold))
                      else
                        Text(
                          tx('Faltan ${e.paradasRestantes} de ${e.paradasTotales} paradas · ${(e.metrosParaBajar / 1000).toStringAsFixed(1)} km'
                                  '${e.minutosRestantes == null ? '' : ' · unos ${e.minutosRestantes} min'}',
                              '${e.paradasRestantes} of ${e.paradasTotales} stops left · ${(e.metrosParaBajar / 1000).toStringAsFixed(1)} km'
                                  '${e.minutosRestantes == null ? '' : ' · about ${e.minutosRestantes} min'}'),
                        ),
                      if (e != null && e.fueraDelRecorrido)
                        Text(tx('Parece que no vas sobre el recorrido de esta ruta.', "You don't seem to be on this route."),
                            style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final extra = e == null
                                  ? ''
                                  : tx(' Voy a ${e.paradasRestantes} paradas de bajarme.', ' I am ${e.paradasRestantes} stops from my stop.');
                              Share.share(widget.textoCompartir + extra);
                            },
                            icon: const Icon(Icons.share),
                            label: Text(tx('Compartir', 'Share')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _tramo < _buses.length - 1
                              ? FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: kAcento),
                                  onPressed: () {
                                    setState(() => _tramo++);
                                    _iniciarTramo();
                                  },
                                  child: Text(tx('Ya tomé la ${_buses[_tramo + 1].ruta!.nombre}', 'On ${_buses[_tramo + 1].ruta!.nombre} now')),
                                )
                              : FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: kAcento),
                                  onPressed: _terminar,
                                  child: Text(tx('Terminar', 'Finish')),
                                ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(tx('Tu ubicación solo se usa en tu teléfono. El seguimiento se apaga solo en 2 horas.',
                              'Your location is only used on your phone. Tracking turns off after 2 hours.'),
                          textAlign: TextAlign.center, style: const TextStyle(color: kTextoSecundario, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
