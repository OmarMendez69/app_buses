/// Validaciones básicas reutilizables en los formularios.
class Validadores {
  static String? requerido(String? valor, [String campo = 'Este campo']) {
    if (valor == null || valor.trim().isEmpty) {
      return '$campo es obligatorio';
    }
    return null;
  }

  static String? correo(String? valor) {
    final error = requerido(valor, 'El correo');
    if (error != null) return error;
    final valido = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(valor!.trim());
    return valido ? null : 'Escribe un correo válido';
  }

  static String? contrasena(String? valor) {
    final error = requerido(valor, 'La contraseña');
    if (error != null) return error;
    if (valor!.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }
}
