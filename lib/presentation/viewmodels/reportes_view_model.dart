import 'package:flutter/foundation.dart';

import '../../domain/entities/reporte.dart';

/// Lista de reportes en memoria.
/// TODO (compañero): precargar 2-3 reportes de ejemplo en [_reportes].
/// Mantener los nombres `reportes` y `agregar` (los usan los dashboards).
class ReportesViewModel extends ChangeNotifier {
  final List<Reporte> _reportes = [];

  List<Reporte> get reportes => List.unmodifiable(_reportes);

  void agregar(Reporte reporte) {
    _reportes.insert(0, reporte);
    notifyListeners();
  }
}
