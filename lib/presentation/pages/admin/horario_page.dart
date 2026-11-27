import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';

/// Franjas de servicio de un recorrido por tipo de día:
/// horario de operación y frecuencia mínima/máxima. La base de datos impide empalmes.
class HorarioPage extends StatefulWidget {
  final AppViewModels vms;
  final int idRecorrido;
  const HorarioPage({super.key, required this.vms, required this.idRecorrido});

  @override
  State<HorarioPage> createState() => _HorarioPageState();
}

class _FranjaEditable {
  int inicio;
  int fin;
  int fmin;
  int fmax;
  String fuente;
  _FranjaEditable(this.inicio, this.fin, this.fmin, this.fmax, this.fuente);

  Franja aFranja(int idRecorrido, TipoDia td) => Franja(
        id: 0,
        idRecorrido: idRecorrido,
        tipoDia: td,
        inicio: inicio,
        fin: fin,
        frecuenciaMin: fmin,
        frecuenciaMax: fmax,
        fuente: fuente,
      );
}

class _HorarioPageState extends State<HorarioPage> {
  TipoDia _td = TipoDia.laborable;
  final Map<TipoDia, List<_FranjaEditable>> _franjas = {};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final cat = widget.vms.catalogo.cat;
    for (final td in TipoDia.values) {
      _franjas[td] = [
        for (final f in cat.franjasDe(widget.idRecorrido, td)) _FranjaEditable(f.inicio, f.fin, f.frecuenciaMin, f.frecuenciaMax, f.fuente),
      ];
    }
  }

  List<_FranjaEditable> get _lista => _franjas[_td]!;

  Future<int?> _hora(int actual) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: actual ~/ 60 % 24, minute: actual % 60));
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _guardar() async {
    for (final f in _lista) {
      if (f.inicio >= f.fin) {
        avisar(context, 'Cada franja debe terminar después de empezar.');
        return;
      }
      if (f.fmin > f.fmax) {
        avisar(context, 'La frecuencia mínima no puede ser mayor que la máxima.');
        return;
      }
    }
    setState(() => _guardando = true);
    try {
      await widget.vms.admin.guardarFranjas(
        widget.idRecorrido,
        _td,
        _lista.map((f) => f.aFranja(widget.idRecorrido, _td)).toList(),
      );
      await widget.vms.catalogo.refrescar();
      if (mounted) avisar(context, 'Horario de ${_td.etiqueta.toLowerCase()} guardado');
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _copiar() async {
    final destino = await showDialog<TipoDia>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Copiar estas franjas a…'),
        children: [
          for (final td in TipoDia.values)
            if (td != _td) SimpleDialogOption(onPressed: () => Navigator.pop(c, td), child: Text(td.etiqueta)),
        ],
      ),
    );
    if (destino == null) return;
    setState(() {
      _franjas[destino] = [for (final f in _lista) _FranjaEditable(f.inicio, f.fin, f.fmin, f.fmax, f.fuente)];
      _td = destino;
    });
    if (mounted) avisar(context, 'Copiado. Revisa y toca Guardar.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario de servicio'),
        actions: [IconButton(icon: const Icon(Icons.copy_all), tooltip: 'Copiar a otro tipo de día', onPressed: _copiar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAcento,
        onPressed: _guardando ? null : _guardar,
        icon: const Icon(Icons.save),
        label: const Text('Guardar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          SegmentedButton<TipoDia>(
            segments: const [
              ButtonSegment(value: TipoDia.laborable, label: Text('L–V')),
              ButtonSegment(value: TipoDia.sabado, label: Text('Sábado')),
              ButtonSegment(value: TipoDia.domingoFestivo, label: Text('Dom/fest.')),
            ],
            selected: {_td},
            onSelectionChanged: (s) => setState(() => _td = s.first),
          ),
          const SizedBox(height: 8),
          const Text(
            'Divide el día en franjas si la frecuencia cambia (ej. 6:00–9:00 cada 8–12 min, 9:00–21:30 cada 12–18 min). '
            'Las franjas no se pueden empalmar.',
            style: TextStyle(color: kTextoSecundario, fontSize: 12),
          ),
          for (var i = 0; i < _lista.length; i++)
            Card(
              key: ObjectKey(_lista[i]),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  Row(children: [
                    TextButton(
                      onPressed: () async {
                        final h = await _hora(_lista[i].inicio);
                        if (h != null) setState(() => _lista[i].inicio = h);
                      },
                      child: Text(textoHora(_lista[i].inicio), style: const TextStyle(fontSize: 18)),
                    ),
                    const Text('a'),
                    TextButton(
                      onPressed: () async {
                        final h = await _hora(_lista[i].fin);
                        if (h != null) setState(() => _lista[i].fin = h);
                      },
                      child: Text(textoHora(_lista[i].fin), style: const TextStyle(fontSize: 18)),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _lista.removeAt(i))),
                  ]),
                  Row(children: [
                    const Text('Cada '),
                    _numero(_lista[i].fmin, (v) => _lista[i].fmin = v),
                    const Text(' a '),
                    _numero(_lista[i].fmax, (v) => _lista[i].fmax = v),
                    const Text(' min'),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _lista[i].fuente,
                      items: const [
                        DropdownMenuItem(value: 'levantamiento', child: Text('Levantamiento')),
                        DropdownMenuItem(value: 'concesionario', child: Text('Concesionario')),
                        DropdownMenuItem(value: 'municipio', child: Text('Municipio')),
                        DropdownMenuItem(value: 'oficial', child: Text('Oficial')),
                      ],
                      onChanged: (v) => setState(() => _lista[i].fuente = v ?? 'levantamiento'),
                    ),
                  ]),
                ]),
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() {
              final inicio = _lista.isEmpty ? 6 * 60 : _lista.last.fin;
              _lista.add(_FranjaEditable(inicio, (inicio + 180).clamp(0, 23 * 60 + 59), 10, 15, 'levantamiento'));
            }),
            icon: const Icon(Icons.add),
            label: const Text('Agregar franja'),
          ),
        ],
      ),
    );
  }

  Widget _numero(int valor, void Function(int) alCambiar) => SizedBox(
        width: 48,
        child: TextFormField(
          initialValue: '$valor',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(isDense: true),
          onChanged: (t) {
            final n = int.tryParse(t);
            if (n != null && n >= 1 && n <= 120) alCambiar(n);
          },
        ),
      );
}
