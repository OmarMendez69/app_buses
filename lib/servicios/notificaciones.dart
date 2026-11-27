import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/idioma.dart';
import '../core/tiempo.dart';
import '../domain/catalogo.dart';
import '../domain/entities/viaje.dart';
import '../domain/servicios/planificador.dart';
import '../firebase_options.dart';

/// Notificaciones push (Firebase Cloud Messaging) y locales (programadas en el teléfono).
///
/// Canales de Android:
///   avisos         avisos de servicio de las rutas que sigues
///   tablon         respuestas a tus publicaciones
///   recordatorios  último camión y hora de salida de tus viajes guardados
///   viaje          seguimiento y alarma de bajada
class Notificaciones {
  static final Notificaciones instancia = Notificaciones._();
  Notificaciones._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _firebaseListo = false;
  bool _localListo = false;

  bool get pushDisponible => _firebaseListo;
  bool get _movil => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _avisos = AndroidNotificationDetails('avisos', 'Avisos de servicio',
      channelDescription: 'Desvíos y cambios en las rutas que sigues', importance: Importance.high, priority: Priority.high);
  static const _tablon = AndroidNotificationDetails('tablon', 'Tablón', channelDescription: 'Respuestas a tus publicaciones');
  static const _recordatorios = AndroidNotificationDetails('recordatorios', 'Recordatorios',
      channelDescription: 'Último camión y hora de salida', importance: Importance.high, priority: Priority.high);
  static const viajeDetalles = AndroidNotificationDetails('viaje', 'Viaje en curso',
      channelDescription: 'Alarma de bajada', importance: Importance.max, priority: Priority.max, enableVibration: true, playSound: true);

  /// Se llama una vez al abrir la app. Si Firebase no está configurado, la app funciona sin push.
  Future<void> iniciar() async {
    if (!_movil) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final canal in const [
      AndroidNotificationChannel('avisos', 'Avisos de servicio', importance: Importance.high),
      AndroidNotificationChannel('tablon', 'Tablón'),
      AndroidNotificationChannel('recordatorios', 'Recordatorios', importance: Importance.high),
      AndroidNotificationChannel('viaje', 'Viaje en curso', importance: Importance.max),
    ]) {
      await android?.createNotificationChannel(canal);
    }
    await android?.requestNotificationsPermission();
    _localListo = true;

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen(_mostrarPush);
      _firebaseListo = true;
    } catch (e) {
      debugPrint('Firebase no configurado: $e (la app sigue funcionando sin push)');
    }
  }

  void _mostrarPush(RemoteMessage m) {
    final n = m.notification;
    if (n == null || !_localListo) return;
    final detalles = m.data['tipo'] == 'comentario' ? _tablon : _avisos;
    _local.show(m.hashCode & 0x7fffffff, n.title, n.body, NotificationDetails(android: detalles));
  }

  Future<void> mostrar(int id, String titulo, String cuerpo, {AndroidNotificationDetails detalles = _recordatorios}) async {
    if (!_localListo) return;
    await _local.show(id, titulo, cuerpo, NotificationDetails(android: detalles));
  }

  Future<String?> token() async {
    if (!_firebaseListo) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<String> get tokenRenovado => _firebaseListo ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  /// Topics: `general` y `ruta_<id>` para las rutas que sigues.
  Future<void> sincronizarTopics({required Set<int> rutas, required Set<int> antes, required bool rutasOn, required bool generalesOn}) async {
    if (!_firebaseListo) return;
    final fm = FirebaseMessaging.instance;
    try {
      if (generalesOn) {
        await fm.subscribeToTopic('general');
      } else {
        await fm.unsubscribeFromTopic('general');
      }
      for (final id in antes.union(rutas)) {
        if (rutasOn && rutas.contains(id)) {
          await fm.subscribeToTopic('ruta_$id');
        } else {
          await fm.unsubscribeFromTopic('ruta_$id');
        }
      }
    } catch (e) {
      debugPrint('Topics: $e');
    }
  }

  // ------------------------------------------------------------------
  // Programadas (sin servidor): último camión y recordatorio de salida.
  // Se recalculan cada vez que se abre la app, para los próximos 7 días.
  // IDs: 100000 + ruta*10 + día   |   200000 + viaje*10 + día
  // ------------------------------------------------------------------
  Future<void> _cancelarRango(int desde, int hasta) async {
    final pendientes = await _local.pendingNotificationRequests();
    for (final p in pendientes) {
      if (p.id >= desde && p.id < hasta) await _local.cancel(p.id);
    }
  }

  Future<void> _programar(int id, String titulo, String cuerpo, DateTime cuando) async {
    if (cuando.isBefore(DateTime.now())) return;
    await _local.zonedSchedule(
      id,
      titulo,
      cuerpo,
      tz.TZDateTime.from(cuando, tz.local),
      const NotificationDetails(android: _recordatorios),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> programarUltimoCamion(Catalogo cat, Set<int> rutas, int minutosAntes) async {
    if (!_localListo) return;
    await _cancelarRango(100000, 200000);
    if (minutosAntes <= 0) return;
    final hoy = DateTime.now();
    for (final idRuta in rutas) {
      final ruta = cat.rutaPorId[idRuta];
      if (ruta == null || !ruta.activa) continue;
      for (var d = 0; d < 7; d++) {
        final dia = DateTime(hoy.year, hoy.month, hoy.day).add(Duration(days: d));
        final ultimo = cat.estadoRuta(idRuta, dia).ultimoServicio;
        if (ultimo == null) continue;
        final cuando = dia.add(Duration(minutes: ultimo - minutosAntes));
        await _programar(
          100000 + idRuta * 10 + d,
          tx('Último camión: ${ruta.nombre}', 'Last bus: ${ruta.nombre}'),
          tx('El servicio termina a las ${textoHora(ultimo)}. Faltan $minutosAntes min.',
              'Service ends at ${textoHora(ultimo)}. $minutosAntes min left.'),
          cuando,
        );
      }
    }
  }

  Future<void> programarRecordatorios(Catalogo cat, List<ViajeGuardado> viajes) async {
    if (!_localListo) return;
    await _cancelarRango(200000, 300000);
    final plan = Planificador(cat);
    final hoy = DateTime.now();
    for (final v in viajes) {
      if (!v.recordatorio || v.id == null) continue;
      for (var d = 0; d < 7; d++) {
        final dia = DateTime(hoy.year, hoy.month, hoy.day).add(Duration(days: d));
        if (!v.dias.contains(dia.weekday)) continue;
        final llegada = dia.add(Duration(minutes: v.llegarAntesDe));
        // Se planea con un margen de 45 min antes de la hora de llegada.
        final r = plan.planear(v.origen, v.destino, llegada.subtract(const Duration(minutes: 45)));
        if (r.opciones.isEmpty) continue;
        final mejor = r.opciones.first;
        final salida = llegada.subtract(Duration(minutes: mejor.maxMinutos + 5));
        final avisos = mejor.enCamion
            .expand((t) => cat.avisosVigentes(salida, idRuta: t.ruta!.id, incluirGenerales: false))
            .toList();
        final extra = avisos.isEmpty ? '' : tx(' Ojo: ${avisos.first.titulo}.', ' Note: ${avisos.first.titulo}.');
        await _programar(
          200000 + v.id! * 10 + d,
          tx('Sal ahora: ${v.nombre}', 'Leave now: ${v.nombre}'),
          tx('Toma ${mejor.resumen} para llegar antes de las ${textoHora(v.llegarAntesDe)}.$extra',
              'Take ${mejor.resumen} to arrive by ${textoHora(v.llegarAntesDe)}.$extra'),
          salida,
        );
      }
    }
  }
}
