import 'package:flutter/foundation.dart';

import '../../domain/entities/ruta_cercana.dart';
import '../../domain/usecases/obtener_rutas_cercanas.dart';

enum EstadoCarga { cargando, exito, error }

class InicioViewModel extends ChangeNotifier {
  final ObtenerRutasCercanas _obtenerRutasCercanas;

  InicioViewModel(this._obtenerRutasCercanas);

  EstadoCarga _estado = EstadoCarga.cargando;
  List<RutaCercana> _rutas = const [];

  EstadoCarga get estado => _estado;
  List<RutaCercana> get rutas => _rutas;

  Future<void> cargarRutas() async {
    _estado = EstadoCarga.cargando;
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
