import 'package:flutter/foundation.dart';

import '../../domain/entities/ruta_cercana.dart';
import '../../domain/usecases/obtener_rutas_cercanas.dart';

enum EstadoCarga { cargando, exito, error }

class InicioViewModel extends ChangeNotifier {
  final ObtenerRutasCercanas _obtenerRutasCercanas;

  InicioViewModel(this._obtenerRutasCercanas);

  EstadoCarga _estado = EstadoCarga.cargando;
  List<RutaCercana> _rutas = const [];
  String _filtro = '';

  EstadoCarga get estado => _estado;
  List<RutaCercana> get rutas => _rutas;

  /// Rutas que coinciden con lo escrito en el buscador.
  /// Si no hay coincidencias la lista queda vacía (estado vacío).
  List<RutaCercana> get rutasFiltradas {
    if (_filtro.isEmpty) return _rutas;
    final f = _filtro.toLowerCase();
    return _rutas
        .where((r) =>
            r.nombre.toLowerCase().contains(f) ||
            r.recorrido.toLowerCase().contains(f) ||
            r.parada.toLowerCase().contains(f))
        .toList();
  }

  void filtrar(String texto) {
    _filtro = texto.trim();
    notifyListeners();
  }

  Future<void> cargarRutas() async {
    _estado = EstadoCarga.cargando;
    _filtro = '';
    notifyListeners();
    try {
      _rutas = await _obtenerRutasCercanas();
      _estado = EstadoCarga.exito;
    } catch (_) {
      _estado = EstadoCarga.error;
    }
    notifyListeners();
  }
}
