import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/comunidad.dart';

/// Tablón: publicaciones, comentarios, "útil" y denuncias.
class ComunidadRepository {
  final SupabaseClient _db;
  ComunidadRepository(this._db);

  // Se indica la relación exacta (!nombre_fk) porque perfil y comentario se conectan con
  // publicacion por varios caminos (autor, votos, comentarios, denuncias).
  static const _campos = '*, perfil:perfil!publicacion_id_usuario_fkey(nombre), voto_util(id_usuario), '
      'comentario:comentario!comentario_id_publicacion_fkey(count)';

  String? get _yo => _db.auth.currentUser?.id;

  Future<List<Publicacion>> publicaciones({
    CategoriaPublicacion? categoria,
    Set<CategoriaPublicacion>? categorias,
    DateTime? desde,
    int? idRuta,
    Set<int>? rutas,
    String? deUsuario,
    int limite = 60,
  }) async {
    var q = _db.from('publicacion').select(_campos);
    if (categoria != null) q = q.eq('categoria', categoria.db);
    if (categorias != null && categorias.isNotEmpty) {
      q = q.inFilter('categoria', categorias.map((c) => c.db).toList());
    }
    if (desde != null) q = q.gte('creado_en', desde.toUtc().toIso8601String());
    if (idRuta != null) q = q.eq('id_ruta', idRuta);
    if (rutas != null && rutas.isNotEmpty) q = q.inFilter('id_ruta', rutas.toList());
    if (deUsuario != null) {
      q = q.eq('id_usuario', deUsuario);
    } else {
      q = q.eq('estado', 'visible');
    }
    final filas = await q.order('creado_en', ascending: false).limit(limite);
    return filas.map((j) => Publicacion.fromJson(j, miId: _yo)).toList();
  }

  Future<Publicacion?> publicacion(int id) async {
    final j = await _db.from('publicacion').select(_campos).eq('id_publicacion', id).maybeSingle();
    return j == null ? null : Publicacion.fromJson(j, miId: _yo);
  }

  Future<List<Comentario>> comentarios(int idPublicacion) async {
    final filas = await _db
        .from('comentario')
        .select('*, perfil:perfil!comentario_id_usuario_fkey(nombre)')
        .eq('id_publicacion', idPublicacion)
        .eq('estado', 'visible')
        .order('creado_en');
    return filas.map(Comentario.fromJson).toList();
  }

  Future<void> publicar(CategoriaPublicacion categoria, String texto, {int? idRuta, int? idParada}) =>
      _db.from('publicacion').insert({
        'categoria': categoria.db,
        'texto': texto.trim(),
        'id_ruta': idRuta,
        'id_parada': idParada,
      });

  Future<void> comentar(int idPublicacion, String texto) =>
      _db.from('comentario').insert({'id_publicacion': idPublicacion, 'texto': texto.trim()});

  Future<void> marcarUtil(int idPublicacion, bool util) async {
    if (util) {
      await _db.from('voto_util').upsert({'id_publicacion': idPublicacion, 'id_usuario': _yo});
    } else {
      await _db.from('voto_util').delete().eq('id_publicacion', idPublicacion).eq('id_usuario', _yo!);
    }
  }

  Future<void> denunciar({int? idPublicacion, int? idComentario, required String motivo}) =>
      _db.from('denuncia').insert({
        'id_publicacion': idPublicacion,
        'id_comentario': idComentario,
        'motivo': motivo,
      });

  Future<void> borrarPublicacion(int id) => _db.from('publicacion').delete().eq('id_publicacion', id);
}

/// Mensaje claro para errores de la base de datos (límites, permisos, red).
String mensajeError(Object e) {
  if (e is PostgrestException) {
    final m = e.message;
    if (m.startsWith('LIMITE: ')) return m.substring(8);
    if (e.code == '23505') return 'Ya lo habías hecho antes.';
    if (e.code == '42501' || m.contains('row-level security')) return 'No tienes permiso para hacer esto.';
    return m;
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (m.contains('already registered')) return 'Ese correo ya tiene cuenta.';
    if (m.contains('email not confirmed')) return 'Confirma tu correo antes de entrar (revisa tu bandeja).';
    return e.message;
  }
  final t = e.toString();
  if (t.contains('SocketException') || t.contains('ClientException') || t.contains('Failed host lookup')) {
    return 'Sin conexión a internet.';
  }
  return t;
}
