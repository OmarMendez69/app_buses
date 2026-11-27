import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../domain/catalogo.dart';
import '../../../domain/entities/viaje.dart';
import '../../../domain/servicios/planificador.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/selector_punto.dart';
import 'planificador_page.dart';

/// Viajes frecuentes con recordatorio de salida.
class ViajesGuardadosPage extends StatelessWidget {
  final AppViewModels vms;
  const ViajesGuardadosPage({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx('Viajes guardados', 'Saved trips'))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAcento,
        onPressed: () => abrir(context, EditarViajePage(vms: vms)),
        icon: const Icon(Icons.add),
        label: Text(tx('Nuevo', 'New')),
      ),
      body: ListenableBuilder(
        listenable: vms.viajes,
        builder: (context, _) {
          final viajes = vms.viajes.viajes;
          if (viajes.isEmpty) {
            return EstadoVacio(
              mensaje: tx('Guarda tus viajes de todos los días (casa → escuela) y te aviso cuándo salir.',
                  'Save your daily trips (home → school) and I will tell you when to leave.'),
              icono: Icons.bookmarks_outlined,
            );
          }
          final cat = vms.catalogo.cat;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final v in viajes)
                Card(
                  child: ListTile(
                    title: Text(v.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${v.origen.nombre} → ${v.destino.nombre}\n'
                      '${v.dias.map((d) => diasSemanaCortos[d - 1]).join(' ')} · ${tx('llegar antes de', 'arrive by')} ${textoHora(v.llegarAntesDe)}\n'
                      '${_salida(v, cat)}',
                    ),
                    isThreeLine: true,
                    onTap: () => abrir(context, PlanificadorPage(vms: vms, origenInicial: v.origen, destinoInicial: v.destino)),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: v.recordatorio,
                          activeTrackColor: kAcento,
                          onChanged: (_) => vms.viajes.alternarRecordatorio(v),
                        ),
                      ],
                    ),
                    onLongPress: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(tx('¿Borrar "${v.nombre}"?', 'Delete "${v.nombre}"?')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx('Cancelar', 'Cancel'))),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tx('Borrar', 'Delete'))),
                          ],
                        ),
                      );
                      if (ok == true) await vms.viajes.borrar(v);
                    },
                  ),
                ),
              Text(tx('Mantén presionado un viaje para borrarlo.', 'Long-press a trip to delete it.'),
                  style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  String _salida(ViajeGuardado v, Catalogo cat) {
    final hoy = DateTime.now();
    final llegada = DateTime(hoy.year, hoy.month, hoy.day).add(Duration(minutes: v.llegarAntesDe));
    final r = Planificador(cat).planear(v.origen, v.destino, llegada.subtract(const Duration(minutes: 45)));
    if (r.opciones.isEmpty) return r.mensaje ?? tx('Sin opciones de viaje', 'No trip options');
    final mejor = r.opciones.first;
    final salida = llegada.subtract(Duration(minutes: mejor.maxMinutos + 5));
    return tx('Sal a las ${textoHora(minutosDelDia(salida))} · ${mejor.resumen}', 'Leave at ${textoHora(minutosDelDia(salida))} · ${mejor.resumen}');
  }
}

class EditarViajePage extends StatefulWidget {
  final AppViewModels vms;
  final PuntoNombrado? origen;
  final PuntoNombrado? destino;
  const EditarViajePage({super.key, required this.vms, this.origen, this.destino});

  @override
  State<EditarViajePage> createState() => _EditarViajePageState();
}

class _EditarViajePageState extends State<EditarViajePage> {
  final _nombre = TextEditingController();
  PuntoNombrado? _origen;
  PuntoNombrado? _destino;
  final Set<int> _dias = {1, 2, 3, 4, 5};
  TimeOfDay _llegar = const TimeOfDay(hour: 7, minute: 0);
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _origen = widget.origen;
    _destino = widget.destino;
    if (_destino != null) _nombre.text = _destino!.nombre;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty || _origen == null || _destino == null || _dias.isEmpty) {
      avisar(context, tx('Completa nombre, origen, destino y días.', 'Fill in name, origin, destination and days.'));
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.vms.viajes.guardar(ViajeGuardado(
        nombre: _nombre.text.trim().length > 40 ? _nombre.text.trim().substring(0, 40) : _nombre.text.trim(),
        origen: _origen!,
        destino: _destino!,
        dias: _dias.toList()..sort(),
        llegarAntesDe: _llegar.hour * 60 + _llegar.minute,
        recordatorio: true,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx('Nuevo viaje guardado', 'New saved trip'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CampoTexto(controller: _nombre, etiqueta: tx('Nombre (ej. Casa → UTNG)', 'Name (e.g. Home → School)'), icono: Icons.label_outline, maximo: 40),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.trip_origin, color: Colors.blueAccent),
                title: Text(_origen?.nombre ?? tx('Elige el origen', 'Choose origin')),
                onTap: () async {
                  final p = await elegirPunto(context, widget.vms, titulo: tx('Origen', 'From'));
                  if (p != null) setState(() => _origen = p);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: kAcento),
                title: Text(_destino?.nombre ?? tx('Elige el destino', 'Choose destination')),
                onTap: () async {
                  final p = await elegirPunto(context, widget.vms, titulo: tx('Destino', 'To'));
                  if (p != null) setState(() => _destino = p);
                },
              ),
            ]),
          ),
          TituloSeccion(tx('Días', 'Days')),
          Wrap(spacing: 6, children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(diasSemanaCortos[d - 1]),
                selected: _dias.contains(d),
                onSelected: (v) => setState(() => v ? _dias.add(d) : _dias.remove(d)),
              ),
          ]),
          TituloSeccion(tx('Llegar antes de', 'Arrive by')),
          OutlinedButton.icon(
            onPressed: () async {
              final h = await showTimePicker(context: context, initialTime: _llegar);
              if (h != null) setState(() => _llegar = h);
            },
            icon: const Icon(Icons.schedule),
            label: Text(textoHora(_llegar.hour * 60 + _llegar.minute)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
            onPressed: _guardando ? null : _guardar,
            child: Text(tx('Guardar y activar recordatorio', 'Save and turn on reminder')),
          ),
          const SizedBox(height: 8),
          Text(
            tx('Te aviso a qué hora salir sumando la caminata, el trayecto y la frecuencia máxima de la ruta. También te aviso si hay un desvío ese día.',
                'I will tell you when to leave, adding walking, ride time and the maximum frequency. I will also warn you about detours that day.'),
            style: const TextStyle(color: kTextoSecundario, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
