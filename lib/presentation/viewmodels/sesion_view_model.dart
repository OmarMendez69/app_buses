import 'package:flutter/foundation.dart';

import '../../domain/entities/usuario.dart';

/// Guarda el usuario activo y su rol mientras la app está abierta.
/// Los usuarios viven en memoria (suficiente para esta entrega).
class SesionViewModel extends ChangeNotifier {
  final List<Usuario> _usuarios = [
    const Usuario(
      nombre: 'Admin Demo',
      correo: 'admin@camiones.com',
      contrasena: '123456',
      rol: Rol.admin,
    ),
    const Usuario(
      nombre: 'Alumno Demo',
      correo: 'alumno@camiones.com',
      contrasena: '123456',
      rol: Rol.alumno,
      reputacion: 12,
    ),
    const Usuario(
      nombre: 'Visitante Demo',
      correo: 'visitante@camiones.com',
      contrasena: '123456',
      rol: Rol.visitante,
      reputacion: 3,
    ),
  ];

  Usuario? _actual;

  Usuario? get usuarioActual => _actual;
  Rol? get rol => _actual?.rol;
  int get totalUsuarios => _usuarios.length;

  /// Devuelve true si las credenciales son correctas.
  bool iniciarSesion(String correo, String contrasena) {
    final c = correo.trim().toLowerCase();
    for (final u in _usuarios) {
      if (u.correo == c && u.contrasena == contrasena) {
        _actual = u;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Devuelve false si el correo ya estaba registrado.
  bool registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required Rol rol,
  }) {
    final c = correo.trim().toLowerCase();
    if (_usuarios.any((u) => u.correo == c)) return false;
    final nuevo = Usuario(
      nombre: nombre.trim(),
      correo: c,
      contrasena: contrasena,
      rol: rol,
    );
    _usuarios.add(nuevo);
    _actual = nuevo;
    notifyListeners();
    return true;
  }

  void cerrarSesion() {
    _actual = null;
    notifyListeners();
  }
}
