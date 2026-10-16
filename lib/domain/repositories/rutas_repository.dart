import '../entities/ruta_cercana.dart';

abstract class RutasRepository {
  Future<List<RutaCercana>> obtenerRutasCercanas();
}
