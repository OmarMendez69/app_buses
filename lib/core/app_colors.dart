import 'package:flutter/material.dart';

const Color kFondo = Color(0xFF0D0D0D);
const Color kSuperficie = Color(0xFF1A1A1A);
const Color kBorde = Color(0xFF2E2E2E);
const Color kAcento = Color(0xFFE53935);
const Color kTextoSecundario = Color(0xFF9E9E9E);
const Color kVerde = Color(0xFF66BB6A);
const Color kAmbar = Color(0xFFFFB300);

/// Convierte "#E53935" en Color.
Color colorDesdeHex(String hex) {
  final limpio = hex.replaceAll('#', '');
  return Color(int.parse('FF$limpio', radix: 16));
}

/// Convierte un Color en "#RRGGBB".
String hexDesdeColor(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

ThemeData temaApp() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kFondo,
    colorScheme: const ColorScheme.dark(primary: kAcento, secondary: kAcento, surface: kSuperficie),
    appBarTheme: const AppBarTheme(backgroundColor: kSuperficie, elevation: 0),
    cardTheme: CardThemeData(
      color: kSuperficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorde),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: kSuperficie),
    useMaterial3: true,
  );
}
