import 'package:latlong2/latlong.dart';

import '../../core/idioma.dart';
import 'transporte.dart';

/// Un lugar de origen o destino elegido por el usuario.
class PuntoNombrado {
  final String nombre;
  final LatLng punto;
  const PuntoNombrado(this.nombre, this.punto);
}

enum TipoTramo { caminar, camion }

/// Un paso del viaje: caminar o ir en camión.
class Tramo {
  final TipoTramo tipo;
  final LatLng desde;
  final LatLng hasta;
  final String desdeNombre;
  final String hastaNombre;
  final int minutos;
  final double metros;

  // Solo para tramos en camión
  final Ruta? ruta;
  final Recorrido? recorrido;
  final double avanceSube;
  final double avanceBaja;
  final int? frecuenciaMin;
  final int? frecuenciaMax;
  final int paradasIntermedias;
  final bool minutosEstimados;

  const Tramo({
    required this.tipo,
    required this.desde,
    required this.hasta,
    required this.desdeNombre,
    required this.hastaNombre,
    required this.minutos,
    required this.metros,
    this.ruta,
    this.recorrido,
    this.avanceSube = 0,
    this.avanceBaja = 0,
    this.frecuenciaMin,
    this.frecuenciaMax,
    this.paradasIntermedias = 0,
    this.minutosEstimados = false,
  });
}

/// Una opción de viaje propuesta por el planificador.
class OpcionViaje {
  final List<Tramo> tramos;
  final int minMinutos;
  final int maxMinutos;
  final List<String> avisosDemanda;
  final List<Aviso> avisosVigentes;
  final bool soloCaminando;

  const OpcionViaje({
    required this.tramos,
    required this.minMinutos,
    required this.maxMinutos,
    this.avisosDemanda = const [],
    this.avisosVigentes = const [],
    this.soloCaminando = false,
  });

  List<Tramo> get enCamion => tramos.where((t) => t.tipo == TipoTramo.camion).toList();
  int get transbordos => enCamion.isEmpty ? 0 : enCamion.length - 1;
  double get metrosCaminando =>
      tramos.where((t) => t.tipo == TipoTramo.caminar).fold(0.0, (s, t) => s + t.metros);

  String get resumen {
    if (soloCaminando) return tx('Caminando', 'Walking');
    return enCamion.map((t) => t.ruta!.nombre).join(' → ');
  }
}

/// Resultado del planificador
class ResultadoPlan {
  final List<OpcionViaje> opciones;
  final String? mensaje;
  const ResultadoPlan(this.opciones, [this.mensaje]);
}

/// Viaje frecuente guardado ("Casa → UTNG, L–V, llegar antes de 7:00")
class ViajeGuardado {
  final int? id;
  final String nombre;
  final PuntoNombrado origen;
  final PuntoNombrado destino;
  final List<int> dias; // 1 = lunes … 7 = domingo
  final int llegarAntesDe; // minutos desde medianoche
  final bool recordatorio;

  const ViajeGuardado({
    this.id,
    required this.nombre,
    required this.origen,
    required this.destino,
    required this.dias,
    required this.llegarAntesDe,
    required this.recordatorio,
  });

  factory ViajeGuardado.fromJson(Map<String, dynamic> j) {
    final h = (j['llegar_antes_de'] as String).split(':');
    return ViajeGuardado(
      id: j['id_viaje'] as int?,
      nombre: j['nombre'] as String,
      origen: PuntoNombrado(j['origen_nombre'] as String,
          LatLng((j['origen_lat'] as num).toDouble(), (j['origen_lng'] as num).toDouble())),
      destino: PuntoNombrado(j['destino_nombre'] as String,
          LatLng((j['destino_lat'] as num).toDouble(), (j['destino_lng'] as num).toDouble())),
      dias: (j['dias'] as List).map((e) => (e as num).toInt()).toList(),
      llegarAntesDe: int.parse(h[0]) * 60 + int.parse(h[1]),
      recordatorio: j['recordatorio'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id_viaje': id,
        'nombre': nombre,
        'origen_nombre': origen.nombre,
        'origen_lat': origen.punto.latitude,
        'origen_lng': origen.punto.longitude,
        'destino_nombre': destino.nombre,
        'destino_lat': destino.punto.latitude,
        'destino_lng': destino.punto.longitude,
        'dias': dias,
        'llegar_antes_de': '${(llegarAntesDe ~/ 60).toString().padLeft(2, '0')}:${(llegarAntesDe % 60).toString().padLeft(2, '0')}',
        'recordatorio': recordatorio,
      };

  ViajeGuardado copyWith({int? id, bool? recordatorio}) => ViajeGuardado(
        id: id ?? this.id,
        nombre: nombre,
        origen: origen,
        destino: destino,
        dias: dias,
        llegarAntesDe: llegarAntesDe,
        recordatorio: recordatorio ?? this.recordatorio,
      );
}
