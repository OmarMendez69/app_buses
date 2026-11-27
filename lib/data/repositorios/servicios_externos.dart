import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/geo.dart';
import '../../domain/entities/viaje.dart';

/// Caminata real (OpenRouteService) y búsqueda de direcciones (Nominatim),
/// siempre a través de las Edge Functions para no exponer llaves.
class ServiciosExternos {
  final SupabaseClient _db;
  ServiciosExternos(this._db);

  /// Devuelve (metros, minutos, puntos) o null si no hay internet o se agotó el límite.
  Future<(double, int, List<LatLng>)?> rutaAPie(LatLng desde, LatLng hasta) async {
    try {
      final r = await _db.functions.invoke('ruta-a-pie', body: {
        'origen': [desde.longitude, desde.latitude],
        'destino': [hasta.longitude, hasta.latitude],
      });
      final d = r.data as Map<String, dynamic>;
      if (d['error'] != null) return null;
      return (
        (d['distancia_m'] as num).toDouble(),
        ((d['duracion_s'] as num) / 60).ceil(),
        puntosDesdeJson(d['coords']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<PuntoNombrado>> geocodificar(String texto) async {
    try {
      final r = await _db.functions.invoke('geocodificar', body: {'q': texto});
      final lista = r.data;
      if (lista is! List) return [];
      return lista
          .cast<Map<String, dynamic>>()
          .map((j) => PuntoNombrado(j['nombre'] as String, LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble())))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
