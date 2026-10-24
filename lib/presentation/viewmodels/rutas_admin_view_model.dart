import 'package:flutter/foundation.dart';

import '../../domain/entities/ruta.dart';

/// Rutas que gestiona el administrador (en memoria).
class RutasAdminViewModel extends ChangeNotifier {
  final List<Ruta> _rutas = [
    const Ruta(
      id: 1,
      nombre: 'Centro – UTNG',
      color: 'Rojo',
      frecuenciaAproxMin: 15,
      activa: true,
    ),
    const Ruta(
      id: 2,
      nombre: 'Col. Cruz Blanca – Centro',
      color: 'Azul',
      frecuenciaAproxMin: 20,
      activa: true,
    ),
    const Ruta(
      id: 3,
      nombre: 'Terminal – UTNG',
      color: 'Verde',
      frecuenciaAproxMin: 25,
      activa: true,
    ),
  ];
  int _siguienteId = 4;

  List<Ruta> get rutas => List.unmodifiable(_rutas);
  int get totalActivas => _rutas.where((r) => r.activa).length;

  bool existeNombre(String nombre, {int? exceptoId}) {
    final n = nombre.trim().toLowerCase();
    return _rutas.any((r) => r.id != exceptoId && r.nombre.toLowerCase() == n);
  }

  void agregar({
    required String nombre,
    required String color,
    required int frecuenciaAproxMin,
    required bool activa,
  }) {
    _rutas.add(Ruta(
      id: _siguienteId++,
      nombre: nombre.trim(),
      color: color,
      frecuenciaAproxMin: frecuenciaAproxMin,
      activa: activa,
    ));
    notifyListeners();
  }

  void actualizar(Ruta ruta) {
    final i = _rutas.indexWhere((r) => r.id == ruta.id);
    if (i == -1) return;
    _rutas[i] = ruta;
    notifyListeners();
  }
}
