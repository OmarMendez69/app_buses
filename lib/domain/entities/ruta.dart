/// Ruta del modelo de dominio (tabla Ruta).
class Ruta {
  final int id;
  final String nombre;
  final String color;
  final int frecuenciaAproxMin;
  final bool activa;

  const Ruta({
    required this.id,
    required this.nombre,
    required this.color,
    required this.frecuenciaAproxMin,
    required this.activa,
  });

  Ruta copyWith({
    String? nombre,
    String? color,
    int? frecuenciaAproxMin,
    bool? activa,
  }) {
    return Ruta(
      id: id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
      frecuenciaAproxMin: frecuenciaAproxMin ?? this.frecuenciaAproxMin,
      activa: activa ?? this.activa,
    );
  }
}
