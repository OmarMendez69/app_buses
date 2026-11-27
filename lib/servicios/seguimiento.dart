import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/geo.dart';
import '../core/idioma.dart';
import '../domain/catalogo.dart';
import 'notificaciones.dart';

/// Estado del viaje en curso, calculado con el GPS del propio teléfono.
class EstadoSeguimiento {
  final LatLng posicion;
  final double avance;
  final double metrosParaBajar;
  final int paradasRestantes;
  final int paradasTotales;
  final int? minutosRestantes;
  final bool fueraDelRecorrido;
  final bool llegando;

  const EstadoSeguimiento({
    required this.posicion,
    required this.avance,
    required this.metrosParaBajar,
    required this.paradasRestantes,
    required this.paradasTotales,
    required this.minutosRestantes,
    required this.fueraDelRecorrido,
    required this.llegando,
  });
}

/// Por qué terminó el seguimiento (para decírselo al usuario).
enum FinSeguimiento { llegaste, tiempo, manual }

/// "Avísame cuando llegue": sigue tu posición sobre TU tramo del recorrido
/// (de donde subes a donde bajas) y suena/vibra unos 300 m antes de tu bajada.
/// La ubicación no sale del teléfono. Se apaga sola al llegar o después de 2 horas.
class Seguimiento extends ChangeNotifier {
  StreamSubscription<Position>? _sub;
  Timer? _limite;
  RecorridoGeo? geo;
  double _avanceSube = 0;
  double _avanceBaja = 0;
  String nombreBajada = '';
  EstadoSeguimiento? estado;
  bool _alarmaDada = false;
  String? error;
  FinSeguimiento? fin;

  /// Solo el tramo del viaje. Proyectar sobre él (y no sobre todo el recorrido) evita
  /// ubicarte en el regreso cuando la ruta va y vuelve por la misma calle.
  Linea? _tramo;

  /// Posición de cada parada intermedia, en metros desde donde subes.
  List<double> _paradasTramo = const [];

  bool get activo => _sub != null;

  /// Puntos del tramo para dibujarlo (también funciona en circuitos que dan la vuelta).
  List<LatLng> get tramoPuntos => _tramo?.puntos ?? const [];

  static Future<bool> pedirPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<void> iniciar(RecorridoGeo g, double avanceSube, double avanceBaja, String bajada) async {
    await detener();
    error = null;
    if (!await pedirPermiso()) {
      error = tx('Activa la ubicación para usar el seguimiento.', 'Turn on location to use tracking.');
      notifyListeners();
      return;
    }
    geo = g;
    _avanceSube = avanceSube;
    _avanceBaja = avanceBaja;
    nombreBajada = bajada;
    _alarmaDada = false;
    fin = null;
    estado = null;

    final total = g.linea.largo;
    final circular = avanceBaja < avanceSube;
    final puntos = circular
        ? [...g.linea.tramo(avanceSube, total), ...g.linea.tramo(0, avanceBaja)]
        : g.linea.tramo(avanceSube, avanceBaja);
    _tramo = Linea(puntos.length >= 2 ? puntos : [g.linea.puntoEn(avanceSube), g.linea.puntoEn(avanceBaja)]);
    final largo = _tramo!.largo;
    final enTramo = <double>[];
    for (final p in g.paradas) {
      final d = circular && p.$2 < avanceSube ? p.$2 + total - avanceSube : p.$2 - avanceSube;
      if (d > 1 && d < largo - 1) enTramo.add(d);
    }
    _paradasTramo = enTramo;

    final LocationSettings ajustes = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: tx('Viaje en curso', 'Trip in progress'),
              notificationText: tx('Te aviso antes de $bajada', "I'll alert you before $bajada"),
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);

    _sub = Geolocator.getPositionStream(locationSettings: ajustes).listen(
      _alMoverse,
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
    _limite = Timer(const Duration(hours: 2), () => detener(motivo: FinSeguimiento.tiempo));
    notifyListeners();
  }

  void _alMoverse(Position p) {
    final g = geo;
    final tramo = _tramo;
    if (g == null || tramo == null) return;
    final punto = LatLng(p.latitude, p.longitude);
    final pr = tramo.proyectar(punto);
    final restante = (tramo.largo - pr.avance).clamp(0.0, double.infinity);
    final fuera = pr.distancia > 150;

    // Minutos con los tiempos medidos de la ruta: se pasa el avance local a avance del recorrido.
    final largoTotal = g.linea.largo;
    final global = largoTotal == 0 ? 0.0 : (_avanceSube + pr.avance) % largoTotal;
    final minutos = restante <= 0 ? 0 : g.minutosEntre(global, _avanceBaja);

    // Para la alarma se tolera más desviación (300 m) por si el trazado no es exacto.
    final cerca = pr.distancia <= 300;
    final llegando = cerca && restante <= Config.avisoBajadaMetros;
    estado = EstadoSeguimiento(
      posicion: punto,
      avance: pr.avance,
      metrosParaBajar: restante,
      paradasRestantes: _paradasTramo.where((d) => d > pr.avance).length,
      paradasTotales: _paradasTramo.length,
      minutosRestantes: minutos,
      fueraDelRecorrido: fuera,
      llegando: llegando,
    );
    notifyListeners();

    if (llegando && !_alarmaDada) {
      _alarmaDada = true;
      HapticFeedback.heavyImpact();
      Notificaciones.instancia.mostrar(
        900001,
        tx('¡Prepárate para bajar!', 'Get ready to get off!'),
        tx('Tu bajada ($nombreBajada) está a menos de 300 m.', 'Your stop ($nombreBajada) is less than 300 m away.'),
        detalles: Notificaciones.viajeDetalles,
      );
    }
    // Llegaste: a menos de 40 m del final de tu tramo y sobre la ruta.
    if (cerca && restante <= 40) detener(motivo: FinSeguimiento.llegaste);
  }

  Future<void> detener({FinSeguimiento motivo = FinSeguimiento.manual}) async {
    if (_sub != null) fin = motivo;
    await _sub?.cancel();
    _sub = null;
    _limite?.cancel();
    _limite = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _limite?.cancel();
    super.dispose();
  }
}

/// Ubicación actual (una sola lectura), o null si no hay permiso.
Future<LatLng?> ubicacionActual() async {
  try {
    if (!await Seguimiento.pedirPermiso()) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
    );
    return LatLng(p.latitude, p.longitude);
  } catch (_) {
    return null;
  }
}
