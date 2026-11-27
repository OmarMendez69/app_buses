import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'config.dart';

/// Distancia en metros entre dos puntos (fórmula de haversine).
double distanciaM(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double g) => g * math.pi / 180;

/// Minutos caminando, a partir de la distancia en línea recta.
int minutosCaminando(double metrosLineaRecta) =>
    (metrosLineaRecta * Config.factorCalles / Config.velocidadPie).ceil();

/// Resultado de proyectar un punto sobre una línea (el recorrido de una ruta).
class Proyeccion {
  /// Distancia del punto a la línea, en metros
  final double distancia;

  /// Metros recorridos desde el inicio de la línea hasta el punto proyectado
  final double avance;

  /// Punto más cercano sobre la línea
  final LatLng punto;

  const Proyeccion(this.distancia, this.avance, this.punto);
}

/// Línea con sus distancias acumuladas, lista para proyectar puntos.
/// Usa una proyección local plana (suficiente a escala de una ciudad).
class Linea {
  final List<LatLng> puntos;
  final List<double> acumulado;
  final double _lat0;
  final double _cos0;

  Linea._(this.puntos, this.acumulado, this._lat0, this._cos0);

  factory Linea(List<LatLng> puntos) {
    final acum = <double>[0];
    for (var i = 1; i < puntos.length; i++) {
      acum.add(acum.last + distanciaM(puntos[i - 1], puntos[i]));
    }
    final lat0 = puntos.isEmpty ? Config.centroLat : puntos.first.latitude;
    return Linea._(puntos, acum, lat0, math.cos(_rad(lat0)));
  }

  double get largo => acumulado.isEmpty ? 0 : acumulado.last;
  bool get valida => puntos.length >= 2;

  double _x(LatLng p) => p.longitude * 111320 * _cos0;
  double _y(LatLng p) => (p.latitude - _lat0) * 110540;

  Proyeccion proyectar(LatLng p) {
    if (puntos.isEmpty) return Proyeccion(double.infinity, 0, p);
    if (puntos.length == 1) return Proyeccion(distanciaM(p, puntos.first), 0, puntos.first);
    var mejor = Proyeccion(double.infinity, 0, puntos.first);
    final px = _x(p), py = _y(p);
    for (var i = 0; i < puntos.length - 1; i++) {
      final a = puntos[i], b = puntos[i + 1];
      final ax = _x(a), ay = _y(a), bx = _x(b), by = _y(b);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      final d = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
      if (d < mejor.distancia) {
        final punto = LatLng(a.latitude + t * (b.latitude - a.latitude), a.longitude + t * (b.longitude - a.longitude));
        final seg = acumulado[i + 1] - acumulado[i];
        mejor = Proyeccion(d, acumulado[i] + t * seg, punto);
      }
    }
    return mejor;
  }

  /// Punto que está a [avance] metros del inicio.
  LatLng puntoEn(double avance) {
    if (puntos.isEmpty) return const LatLng(Config.centroLat, Config.centroLng);
    if (avance <= 0) return puntos.first;
    for (var i = 1; i < puntos.length; i++) {
      if (acumulado[i] >= avance) {
        final seg = acumulado[i] - acumulado[i - 1];
        final t = seg == 0 ? 0.0 : (avance - acumulado[i - 1]) / seg;
        final a = puntos[i - 1], b = puntos[i];
        return LatLng(a.latitude + t * (b.latitude - a.latitude), a.longitude + t * (b.longitude - a.longitude));
      }
    }
    return puntos.last;
  }

  /// Puntos de la línea entre dos avances (para dibujar solo el tramo del viaje).
  List<LatLng> tramo(double desde, double hasta) {
    if (hasta <= desde) return [puntoEn(desde)];
    final res = <LatLng>[puntoEn(desde)];
    for (var i = 0; i < puntos.length; i++) {
      if (acumulado[i] > desde && acumulado[i] < hasta) res.add(puntos[i]);
    }
    res.add(puntoEn(hasta));
    return res;
  }
}

/// Convierte el trazado guardado en la base ([[lng, lat], ...]) en puntos.
List<LatLng> puntosDesdeJson(dynamic trazado) {
  if (trazado is! List) return [];
  return trazado
      .whereType<List>()
      .where((p) => p.length >= 2)
      .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
      .toList();
}

List<List<double>> puntosAJson(List<LatLng> puntos) =>
    puntos.map((p) => [double.parse(p.longitude.toStringAsFixed(6)), double.parse(p.latitude.toStringAsFixed(6))]).toList();
