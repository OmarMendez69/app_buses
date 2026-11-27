import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/comunidad.dart';

/// Cuentas: inicio de sesión, registro, perfil y eliminación.
class SesionRepository {
  final SupabaseClient _db;
  SesionRepository(this._db);

  User? get usuarioActual => _db.auth.currentUser;

  Stream<AuthState> get cambios => _db.auth.onAuthStateChange;

  Future<void> iniciarSesion(String correo, String contrasena) =>
      _db.auth.signInWithPassword(email: correo.trim().toLowerCase(), password: contrasena);

  /// Devuelve true si la cuenta quedó con sesión iniciada
  /// (false si Supabase pide confirmar el correo primero).
  Future<bool> registrar(String nombre, String correo, String contrasena) async {
    final r = await _db.auth.signUp(
      email: correo.trim().toLowerCase(),
      password: contrasena,
      data: {'nombre': nombre.trim()},
    );
    return r.session != null;
  }

  Future<void> recuperar(String correo) => _db.auth.resetPasswordForEmail(correo.trim().toLowerCase());

  Future<void> cambiarContrasena(String nueva) => _db.auth.updateUser(UserAttributes(password: nueva));

  Future<void> cambiarCorreo(String nuevo) => _db.auth.updateUser(UserAttributes(email: nuevo.trim().toLowerCase()));

  Future<void> cerrarSesion() => _db.auth.signOut();

  Future<Perfil?> perfil() async {
    final u = usuarioActual;
    if (u == null) return null;
    final j = await _db.from('perfil').select().eq('id', u.id).maybeSingle();
    return j == null ? null : Perfil.fromJson(j);
  }

  Future<void> guardarPerfil(Perfil p) => _db.from('perfil').update({
        'nombre': p.nombre.trim(),
        'notif_rutas': p.notifRutas,
        'notif_generales': p.notifGenerales,
        'notif_respuestas': p.notifRespuestas,
        'idioma': p.idioma,
      }).eq('id', p.id);

  Future<(int, int)> resumen(String id) async {
    final j = await _db.from('v_perfil_resumen').select().eq('id', id).maybeSingle();
    if (j == null) return (0, 0);
    return ((j['publicaciones'] as num).toInt(), (j['utiles_recibidos'] as num).toInt());
  }

  Future<void> eliminarCuenta() async {
    await _db.rpc('eliminar_mi_cuenta');
    await _db.auth.signOut();
  }

  // ---- Datos personales sincronizados
  Future<Set<int>> favoritos() async {
    final u = usuarioActual;
    if (u == null) return {};
    final filas = await _db.from('favorito').select('id_ruta').eq('id_usuario', u.id);
    return filas.map((f) => f['id_ruta'] as int).toSet();
  }

  Future<void> agregarFavorito(int idRuta) =>
      _db.from('favorito').upsert({'id_usuario': usuarioActual!.id, 'id_ruta': idRuta});

  Future<void> quitarFavorito(int idRuta) =>
      _db.from('favorito').delete().eq('id_usuario', usuarioActual!.id).eq('id_ruta', idRuta);

  Future<List<Map<String, dynamic>>> viajes() async {
    final u = usuarioActual;
    if (u == null) return [];
    return _db.from('viaje_guardado').select().eq('id_usuario', u.id).order('nombre');
  }

  Future<int> guardarViaje(Map<String, dynamic> datos) async {
    final fila = {...datos, 'id_usuario': usuarioActual!.id};
    final r = await _db.from('viaje_guardado').upsert(fila).select('id_viaje').single();
    return r['id_viaje'] as int;
  }

  Future<void> borrarViaje(int id) => _db.from('viaje_guardado').delete().eq('id_viaje', id);

  Future<void> registrarDispositivo(String token, String plataforma) async {
    final u = usuarioActual;
    if (u == null) return;
    await _db.from('dispositivo').upsert({
      'token_fcm': token,
      'id_usuario': u.id,
      'plataforma': plataforma,
      'actualizado_en': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
