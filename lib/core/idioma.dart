import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idioma de la interfaz (español / inglés).
/// Uso en pantallas: Text(tx('Rutas', 'Routes'))
/// Los nombres de rutas, paradas y lugares no se traducen.
class Idioma extends ChangeNotifier {
  static String codigo = 'es';
  static const _clave = 'idioma';

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    codigo = prefs.getString(_clave) ?? 'es';
    notifyListeners();
  }

  Future<void> cambiar(String nuevo) async {
    if (nuevo != 'es' && nuevo != 'en') return;
    codigo = nuevo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, nuevo);
    notifyListeners();
  }
}

String tx(String es, String en) => Idioma.codigo == 'en' ? en : es;
