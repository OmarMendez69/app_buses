import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../domain/entities/transporte.dart';
import '../../../domain/servicios/hora_pico.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Hora pico = horarios de alta demanda: entradas y salidas de escuelas,
/// cambios de turno y tianguis de los lugares cercanos a la ruta.
/// Son hechos con fuente; la app no adivina qué tan lleno va el camión.
class HoraPicoPage extends StatefulWidget {
  final AppViewModels vms;
  final int? idRuta;
  const HoraPicoPage({super.key, required this.vms, this.idRuta});

  @override
  State<HoraPicoPage> createState() => _HoraPicoPageState();
}

class _HoraPicoPageState extends State<HoraPicoPage> {
  int? _ruta;
  late TipoDia _tipoDia;

  @override
  void initState() {
    super.initState();
    final cat = widget.vms.catalogo.cat;
    _ruta = widget.idRuta ?? (cat.rutasActivas.isEmpty ? null : cat.rutasActivas.first.id);
    _tipoDia = cat.tipoDia(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final eventos = _ruta == null ? <EventoDemanda>[] : horaPicoDeRuta(cat, _ruta!, _tipoDia);
    final porHora = <int, List<EventoDemanda>>{};
    for (final e in eventos) {
      porHora.putIfAbsent(e.hora, () => []).add(e);
    }
    final ahora = minutosDelDia(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(tx('Hora pico', 'Peak hours'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tx('Horarios de entrada y salida de escuelas, trabajos y tianguis cerca de la ruta. A esas horas el camión suele ir más lleno.',
                'Start and end times of schools, workplaces and markets near the route. Buses are usually fuller at these times.'),
            style: const TextStyle(color: kTextoSecundario),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _ruta,
            decoration: InputDecoration(labelText: tx('Ruta', 'Route'), filled: true, fillColor: kSuperficie),
            items: [for (final r in cat.rutasActivas) DropdownMenuItem(value: r.id, child: Text(r.nombre))],
            onChanged: (v) => setState(() => _ruta = v),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TipoDia>(
            segments: [
              ButtonSegment(value: TipoDia.laborable, label: Text(tx('L–V', 'Mon–Fri'))),
              ButtonSegment(value: TipoDia.sabado, label: Text(tx('Sáb', 'Sat'))),
              ButtonSegment(value: TipoDia.domingoFestivo, label: Text(tx('Dom', 'Sun'))),
            ],
            selected: {_tipoDia},
            onSelectionChanged: (s) => setState(() => _tipoDia = s.first),
          ),
          const SizedBox(height: 8),
          if (porHora.isEmpty)
            EstadoVacio(
              mensaje: tx('Aún no hay horarios registrados de lugares cerca de esta ruta.', 'No schedules recorded yet for places near this route.'),
              icono: Icons.schedule,
            ),
          for (final entrada in porHora.entries)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: (entrada.key - ahora).abs() <= 30 && _tipoDia == cat.tipoDia(DateTime.now()) ? kAcento : kBorde),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(textoHora(entrada.key), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in entrada.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text.rich(TextSpan(children: [
                                TextSpan(text: '${e.horario.evento.etiqueta} · ', style: const TextStyle(color: kAmbar)),
                                TextSpan(text: e.lugar.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (e.horario.diaSemana != null) TextSpan(text: ' (${nombreDiaSemana(e.horario.diaSemana!)})'),
                                if (e.horario.descripcion != null) TextSpan(text: ' · ${e.horario.descripcion}'),
                                TextSpan(
                                  text: '\n${tx('Fuente', 'Source')}: ${etiquetaFuente(e.horario.fuente)}',
                                  style: const TextStyle(color: kTextoSecundario, fontSize: 12),
                                ),
                              ])),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
