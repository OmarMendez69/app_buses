import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guardado local en el teléfono: catálogo (modo sin conexión),
/// favoritos y viajes del visitante, y preferencias.
class CacheLocal {
  static const _catalogo = 'catalogo_v1';
  static const _favoritos = 'favoritos_v1';
  static const _viajes = 'viajes_v1';
  static const _visitante = 'modo_visitante';
  static const _notifVisitante = 'notif_visitante_v1';
  static const _ultimoCamionMin = 'ultimo_camion_min';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  Future<Map<String, dynamic>?> leerCatalogo() async {
    final texto = (await _p).getString(_catalogo);
    if (texto == null) return null;
    try {
      return jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarCatalogo(Map<String, dynamic> datos) async =>
      (await _p).setString(_catalogo, jsonEncode(datos));

  Future<Set<int>> leerFavoritos() async =>
      ((await _p).getStringList(_favoritos) ?? const []).map(int.parse).toSet();

  Future<void> guardarFavoritos(Set<int> ids) async =>
      (await _p).setStringList(_favoritos, ids.map((e) => e.toString()).toList());

  Future<List<Map<String, dynamic>>> leerViajes() async {
    final texto = (await _p).getString(_viajes);
    if (texto == null) return [];
    return (jsonDecode(texto) as List).cast<Map<String, dynamic>>();
  }

  Future<void> guardarViajes(List<Map<String, dynamic>> viajes) async =>
      (await _p).setString(_viajes, jsonEncode(viajes));

  Future<bool> modoVisitante() async => (await _p).getBool(_visitante) ?? false;
  Future<void> guardarModoVisitante(bool v) async => (await _p).setBool(_visitante, v);

  /// Preferencias de notificación del visitante: {rutas, generales}
  Future<Map<String, bool>> leerNotifVisitante() async {
    final texto = (await _p).getString(_notifVisitante);
    if (texto == null) return {'rutas': true, 'generales': true};
    return (jsonDecode(texto) as Map).map((k, v) => MapEntry(k as String, v as bool));
  }

  Future<void> guardarNotifVisitante(Map<String, bool> v) async =>
      (await _p).setString(_notifVisitante, jsonEncode(v));

  /// Minutos de anticipación del aviso de último camión (0 = apagado)
  Future<int> ultimoCamionMin() async => (await _p).getInt(_ultimoCamionMin) ?? 40;
  Future<void> guardarUltimoCamionMin(int v) async => (await _p).setInt(_ultimoCamionMin, v);

  /// Borra solo los datos de la app (no la sesión ni el idioma).
  Future<void> borrarTodo() async {
    final p = await _p;
    for (final k in [_catalogo, _favoritos, _viajes, _notifVisitante, _ultimoCamionMin]) {
      await p.remove(k);
    }
  }
}
