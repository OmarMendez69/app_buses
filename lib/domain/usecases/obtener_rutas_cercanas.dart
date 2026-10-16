import '../entities/ruta_cercana.dart';
import '../repositories/rutas_repository.dart';

class ObtenerRutasCercanas {
  final RutasRepository _repositorio;

  const ObtenerRutasCercanas(this._repositorio);

  Future<List<RutaCercana>> call() => _repositorio.obtenerRutasCercanas();
}
