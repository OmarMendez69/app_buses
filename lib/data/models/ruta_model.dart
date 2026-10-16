import '../../domain/entities/ruta_cercana.dart';

class RutaModel {
  final String nombre;
  final String recorrido;
  final String parada;
  final String distancia;
  final String proximo;

  const RutaModel({
    required this.nombre,
    required this.recorrido,
    required this.parada,
    required this.distancia,
    required this.proximo,
  });

  factory RutaModel.fromMap(Map<String, dynamic> mapa) {
    return RutaModel(
      nombre: mapa['nombre'] as String,
      recorrido: mapa['recorrido'] as String,
      parada: mapa['parada'] as String,
      distancia: mapa['distancia'] as String,
      proximo: mapa['proximo'] as String,
    );
  }

  RutaCercana toEntity() {
    return RutaCercana(
      nombre: nombre,
      recorrido: recorrido,
      parada: parada,
      distancia: distancia,
      proximo: proximo,
    );
  }
}
