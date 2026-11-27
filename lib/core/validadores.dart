import 'idioma.dart';

/// Validaciones reutilizables en los formularios.
class Validadores {
  static String? requerido(String? valor, [String? campo]) {
    if (valor == null || valor.trim().isEmpty) {
      return tx('${campo ?? 'Este campo'} es obligatorio', '${campo ?? 'This field'} is required');
    }
    return null;
  }

  static String? nombre(String? valor) {
    final error = requerido(valor, tx('El nombre', 'Name'));
    if (error != null) return error;
    if (valor!.trim().length < 2) return tx('Mínimo 2 caracteres', 'At least 2 characters');
    return null;
  }

  static String? correo(String? valor) {
    final error = requerido(valor, tx('El correo', 'Email'));
    if (error != null) return error;
    final valido = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(valor!.trim());
    return valido ? null : tx('Escribe un correo válido', 'Enter a valid email');
  }

  static String? contrasena(String? valor) {
    final error = requerido(valor, tx('La contraseña', 'Password'));
    if (error != null) return error;
    if (valor!.length < 6) return tx('Mínimo 6 caracteres', 'At least 6 characters');
    return null;
  }

  static String? numero(String? valor, {double min = 0, double max = 9999}) {
    final error = requerido(valor);
    if (error != null) return error;
    final n = double.tryParse(valor!.replaceAll(',', '.'));
    if (n == null) return 'Escribe un número';
    if (n < min || n > max) return 'Debe estar entre ${min.toStringAsFixed(0)} y ${max.toStringAsFixed(0)}';
    return null;
  }

  static String? numeroOpcional(String? valor, {double max = 9999}) {
    if (valor == null || valor.trim().isEmpty) return null;
    return numero(valor, max: max);
  }
}
