import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../domain/entities/viaje.dart';
import '../../../domain/servicios/planificador.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/selector_punto.dart';
import 'viaje_detalle_page.dart';
import 'viajes_guardados_page.dart';

/// "¿A dónde vas?": origen, destino y momento → hasta 3 opciones de viaje.
class PlanificadorPage extends StatefulWidget {
  final AppViewModels vms;
  final PuntoNombrado? origenInicial;
  final PuntoNombrado? destinoInicial;
  final bool comoPestana;

  const PlanificadorPage({super.key, required this.vms, this.origenInicial, this.destinoInicial, this.comoPestana = false});

  @override
  State<PlanificadorPage> createState() => _PlanificadorPageState();
}

class _PlanificadorPageState extends State<PlanificadorPage> {
  PuntoNombrado? _origen;
  PuntoNombrado? _destino;
  DateTime? _momento; // null = ahora
  ResultadoPlan? _resultado;

  @override
  void initState() {
    super.initState();
    _origen = widget.origenInicial;
    _destino = widget.destinoInicial;
    if (_origen == null) {
      final u = widget.vms.catalogo.ubicacion;
      if (u != null) {
        _origen = PuntoNombrado(tx('Mi ubicación', 'My location'), u);
      } else {
        widget.vms.catalogo.actualizarUbicacion().then((u) {
          if (u != null && mounted && _origen == null) {
            setState(() => _origen = PuntoNombrado(tx('Mi ubicación', 'My location'), u));
            _buscar();
          }
        });
      }
    }
    if (_origen != null && _destino != null) WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
  }

  void _buscar() {
    if (_origen == null || _destino == null) return;
    final r = Planificador(widget.vms.catalogo.cat).planear(_origen!, _destino!, _momento ?? DateTime.now());
    setState(() => _resultado = r);
  }

  Future<void> _elegir(bool esOrigen) async {
    final p = await elegirPunto(context, widget.vms, titulo: esOrigen ? tx('Origen', 'From') : tx('Destino', 'To'));
    if (p == null) return;
    setState(() {
      if (esOrigen) {
        _origen = p;
      } else {
        _destino = p;
      }
    });
    _buscar();
  }

  Future<void> _elegirMomento() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(context: context, firstDate: hoy, lastDate: hoy.add(const Duration(days: 30)), initialDate: _momento ?? hoy);
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_momento ?? hoy));
    if (hora == null) return;
    setState(() => _momento = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute));
    _buscar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.comoPestana,
        title: Text(tx('Planear viaje', 'Plan a trip')),
        actions: [
          IconButton(
            tooltip: tx('Viajes guardados', 'Saved trips'),
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => abrir(context, ViajesGuardadosPage(vms: widget.vms)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.trip_origin, color: Colors.blueAccent),
                  title: Text(_origen?.nombre ?? tx('Elige el origen', 'Choose origin')),
                  subtitle: Text(tx('Origen', 'From')),
                  onTap: () => _elegir(true),
                ),
                const Divider(height: 1, color: kBorde),
                ListTile(
                  leading: const Icon(Icons.location_on, color: kAcento),
                  title: Text(_destino?.nombre ?? tx('¿A dónde vas?', 'Where to?')),
                  subtitle: Text(tx('Destino', 'To')),
                  onTap: () => _elegir(false),
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: tx('Invertir', 'Swap'),
                    onPressed: () {
                      setState(() {
                        final o = _origen;
                        _origen = _destino;
                        _destino = o;
                      });
                      _buscar();
                    },
                  ),
                ),
                const Divider(height: 1, color: kBorde),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(_momento == null ? tx('Salir ahora', 'Leave now') : '${tx('Salir', 'Leave')} ${fechaCorta(_momento!)}'),
                  onTap: _elegirMomento,
                  trailing: _momento == null
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () {
                          setState(() => _momento = null);
                          _buscar();
                        }),
                ),
              ],
            ),
          ),
          if (_resultado != null) ..._resultados(_resultado!),
          if (_resultado == null && (_origen == null || _destino == null))
            EstadoVacio(mensaje: tx('Elige origen y destino para ver cómo llegar.', 'Choose origin and destination to see how to get there.'), icono: Icons.alt_route),
        ],
      ),
    );
  }

  List<Widget> _resultados(ResultadoPlan r) {
    return [
      if (r.mensaje != null)
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(r.mensaje!, style: const TextStyle(color: kAmbar))),
      if (r.opciones.isEmpty) EstadoVacio(mensaje: tx('Sin opciones de viaje', 'No trip options'), icono: Icons.search_off),
      for (final o in r.opciones) _TarjetaOpcion(opcion: o, alTocar: () => abrir(context, ViajeDetallePage(vms: widget.vms, opcion: o, origen: _origen!, destino: _destino!))),
      if (r.opciones.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          tx('El tiempo se muestra como rango: el mínimo si el camión llega al momento y el máximo si te toca esperar la frecuencia completa.',
              'Time is shown as a range: minimum if the bus arrives right away, maximum if you wait the full frequency.'),
          style: const TextStyle(color: kTextoSecundario, fontSize: 12),
        ),
        TextButton.icon(
          onPressed: () => abrir(context, EditarViajePage(vms: widget.vms, origen: _origen, destino: _destino)),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(tx('Guardar como viaje frecuente', 'Save as frequent trip')),
        ),
      ],
    ];
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final OpcionViaje opcion;
  final VoidCallback alTocar;
  const _TarjetaOpcion({required this.opcion, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final buses = opcion.enCamion;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: opcion.soloCaminando
                          ? [const Icon(Icons.directions_walk), Text(tx('Caminando', 'Walking'), style: const TextStyle(fontWeight: FontWeight.bold))]
                          : [
                              for (var i = 0; i < buses.length; i++) ...[
                                if (i > 0) const Icon(Icons.chevron_right, size: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: colorDesdeHex(buses[i].ruta!.color), borderRadius: BorderRadius.circular(8)),
                                  child: Text(buses[i].ruta!.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                    ),
                  ),
                  Text(rangoMinutos(opcion.minMinutos, opcion.maxMinutos), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  tx('${opcion.metrosCaminando.round()} m a pie', '${opcion.metrosCaminando.round()} m walking'),
                  if (!opcion.soloCaminando)
                    opcion.transbordos == 0 ? tx('Directo', 'Direct') : tx('1 transbordo', '1 transfer'),
                  for (final b in buses)
                    if (b.frecuenciaMax != null) tx('${b.ruta!.nombre} cada ${rangoMinutos(b.frecuenciaMin!, b.frecuenciaMax!)}', '${b.ruta!.nombre} every ${rangoMinutos(b.frecuenciaMin!, b.frecuenciaMax!)}'),
                ].join(' · '),
                style: const TextStyle(color: kTextoSecundario),
              ),
              if (buses.isNotEmpty)
                Text(tx('Sube en: ${buses.first.desdeNombre}', 'Board at: ${buses.first.desdeNombre}'), style: const TextStyle(fontSize: 13)),
              for (final a in opcion.avisosVigentes.take(1))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('⚠ ${a.titulo}', style: const TextStyle(color: kAmbar, fontSize: 13)),
                ),
              for (final d in opcion.avisosDemanda.take(2))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(d, style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
