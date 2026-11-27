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

/// "Avísame cuando llegue": sigue tu posición sobre el recorrido y
/// suena/vibra unos 300 m antes de tu bajada. La ubicación no sale del teléfono.
/// Se apaga sola al llegar o después de 2 horas.
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

  bool get activo => _sub != null;

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
    _limite = Timer(const Duration(hours: 2), detener);
    notifyListeners();
  }

  void _alMoverse(Position p) {
    final g = geo;
    if (g == null) return;
    final punto = LatLng(p.latitude, p.longitude);
    final pr = g.linea.proyectar(punto);

    final circular = _avanceBaja < _avanceSube;
    double restante;
    if (!circular) {
      restante = _avanceBaja - pr.avance;
    } else {
      restante = pr.avance >= _avanceSube ? (g.linea.largo - pr.avance) + _avanceBaja : _avanceBaja - pr.avance;
    }
    final paradasTotales = g.paradasEntre(_avanceSube, _avanceBaja);
    final paradasRestantes = restante <= 0 ? 0 : g.paradasEntre(pr.avance, _avanceBaja);
    final minutos = g.minutosEntre(pr.avance, _avanceBaja);
    final llegando = restante <= Config.avisoBajadaMetros;

    estado = EstadoSeguimiento(
      posicion: punto,
      avance: pr.avance,
      metrosParaBajar: restante.clamp(0.0, double.infinity),
      paradasRestantes: paradasRestantes,
      paradasTotales: paradasTotales,
      minutosRestantes: restante <= 0 ? 0 : minutos,
      fueraDelRecorrido: pr.distancia > 150,
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
    if (restante < -100) detener(); // ya pasó la bajada
  }

  Future<void> detener() async {
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
