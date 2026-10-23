/// Reporte del paso de un camión (tabla Reporte del modelo de dominio).
/// (Contrato compartido: se pueden AGREGAR campos, no quitar los existentes.)
class Reporte {
  final String ruta;
  final String parada;

  /// 'Ya pasó', 'Viene lleno' o 'No ha pasado'.
  final String tipo;
  final String comentario;
  final DateTime hora;

  const Reporte({
    required this.ruta,
    required this.parada,
    required this.tipo,
    this.comentario = '',
    required this.hora,
  });
}
