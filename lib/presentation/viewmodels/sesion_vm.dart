import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../core/idioma.dart';
import '../../data/cache_local.dart';
import '../../data/repositorios/sesion_repository.dart';
import '../../domain/entities/comunidad.dart';
import '../../servicios/notificaciones.dart';

/// Quién está usando la app: visitante (sin cuenta), usuario o administrador.
class SesionVM extends ChangeNotifier {
  final SesionRepository repo;
  final CacheLocal cache;
  final Idioma idioma;

  SesionVM(this.repo, this.cache, this.idioma);

  Perfil? perfil;
  bool visitante = false;

  /// El admin puede ver la app como la ve un usuario.
  bool vistaUsuario = false;

  bool get conSesion => perfil != null;
  bool get puedePublicar => perfil != null && !perfil!.suspendido;
  bool get esAdmin => perfil?.rol == Rol.admin;

  /// Rol con el que se elige el dashboard.
  Rol get rol {
    if (perfil == null) return Rol.visitante;
    if (perfil!.rol == Rol.admin && !vistaUsuario) return Rol.admin;
    return Rol.usuario;
  }

  /// Al abrir la app: recupera la sesión guardada o el modo visitante.
  Future<bool> restaurar() async {
    if (repo.usuarioActual != null) {
      await _cargarPerfil();
      return true;
    }
    visitante = await cache.modoVisitante();
    notifyListeners();
    return visitante;
  }

  Future<void> _cargarPerfil() async {
    final u = repo.usuarioActual;
    if (u == null) return;
    try {
      perfil = await repo.perfil();
    } catch (_) {
      // Sin internet: perfil mínimo para que la app funcione con lo guardado.
      perfil = Perfil(
        id: u.id,
        nombre: (u.userMetadata?['nombre'] as String?) ?? 'Usuario',
        rol: Rol.usuario,
        suspendido: false,
        notifRutas: true,
        notifGenerales: true,
        notifRespuestas: true,
        idioma: Idioma.codigo,
      );
    }
    if (perfil != null && perfil!.idioma != Idioma.codigo) await idioma.cambiar(perfil!.idioma);
    visitante = false;
    notifyListeners();
    _registrarDispositivo();
  }

  Future<void> _registrarDispositivo() async {
    final token = await Notificaciones.instancia.token();
    if (token == null) return;
    final plataforma = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
    try {
      await repo.registrarDispositivo(token, plataforma);
    } catch (e) {
      debugPrint('Dispositivo: $e');
    }
    Notificaciones.instancia.tokenRenovado.listen((t) => repo.registrarDispositivo(t, plataforma).catchError((_) {}));
  }

  Future<void> iniciarSesion(String correo, String contrasena) async {
    await repo.iniciarSesion(correo, contrasena);
    await cache.guardarModoVisitante(false);
    await _cargarPerfil();
  }

  /// Devuelve true si ya quedó con sesión; false si debe confirmar su correo.
  Future<bool> registrar(String nombre, String correo, String contrasena) async {
    final listo = await repo.registrar(nombre, correo, contrasena);
    if (listo) {
      await cache.guardarModoVisitante(false);
      await _cargarPerfil();
    }
    return listo;
  }

  Future<void> entrarComoVisitante() async {
    visitante = true;
    await cache.guardarModoVisitante(true);
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    try {
      await repo.cerrarSesion();
    } catch (_) {}
    perfil = null;
    visitante = false;
    vistaUsuario = false;
    await cache.guardarModoVisitante(false);
    // Lo de esta cuenta no se queda en el teléfono para la siguiente persona.
    await cache.guardarFavoritos({});
    await cache.guardarViajes([]);
    notifyListeners();
  }

  Future<void> guardarPerfil(Perfil nuevo) async {
    await repo.guardarPerfil(nuevo);
    perfil = nuevo;
    notifyListeners();
  }

  Future<void> eliminarCuenta() async {
    await repo.eliminarCuenta();
    perfil = null;
    visitante = false;
    notifyListeners();
  }

  void alternarVistaUsuario() {
    vistaUsuario = !vistaUsuario;
    notifyListeners();
  }
}
