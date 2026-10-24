import 'package:flutter/foundation.dart';

import '../../domain/entities/reporte.dart';

/// Lista de reportes en memoria (los más recientes van primero).
/// Los nombres `reportes` y `agregar` los usan los dashboards.
class ReportesViewModel extends ChangeNotifier {
  final List<Reporte> _reportes = [
    Reporte(
      ruta: 'Centro – UTNG',
      parada: 'Parada Plaza Principal',
      tipo: 'Ya pasó',
      comentario: 'Pasó puntual, iba con pocos pasajeros.',
      hora: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Reporte(
      ruta: 'Col. Cruz Blanca – Centro',
      parada: 'Parada Av. Hidalgo',
      tipo: 'Viene lleno',
      comentario: 'Casi no cabía nadie, mejor esperar el siguiente.',
      hora: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    Reporte(
      ruta: 'Terminal – UTNG',
      parada: 'Parada Central Camionera',
      tipo: 'No ha pasado',
      hora: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
  ];

  List<Reporte> get reportes => List.unmodifiable(_reportes);

  void agregar(Reporte reporte) {
    _reportes.insert(0, reporte);
    notifyListeners();
  }
}