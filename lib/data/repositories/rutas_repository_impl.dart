import '../../domain/entities/ruta_cercana.dart';
import '../../domain/repositories/rutas_repository.dart';
import '../datasources/rutas_data_source.dart';
import '../models/ruta_model.dart';

class RutasRepositoryImpl implements RutasRepository {
  final RutasDataSource _fuente;

  const RutasRepositoryImpl(this._fuente);

  @override
  Future<List<RutaCercana>> obtenerRutasCercanas() async {
    final datos = await _fuente.obtenerRutas();
    return datos.map((m) => RutaModel.fromMap(m).toEntity()).toList();
  }
}
