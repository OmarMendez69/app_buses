import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/geo.dart';
import '../../core/tiempo.dart';
import '../../domain/entities/transporte.dart';

class UsuarioAdmin {
  final String id;
  final String nombre;
  final String correo;
  final bool esAdmin;
  final bool suspendido;
  final DateTime creadoEn;
  final int publicaciones;

  const UsuarioAdmin(this.id, this.nombre, this.correo, this.esAdmin, this.suspendido, this.creadoEn, this.publicaciones);

  factory UsuarioAdmin.fromJson(Map<String, dynamic> j) => UsuarioAdmin(
        j['id'] as String,
        j['nombre'] as String,
        j['correo'] as String? ?? '',
        j['rol'] == 'admin',
        j['estado'] == 'suspendida',
        DateTime.parse(j['creado_en'] as String).toLocal(),
        (j['publicaciones'] as num).toInt(),
      );
}

class DenunciaAdmin {
  final int id;
  final String motivo;
  final DateTime creadoEn;
  final int? idPublicacion;
  final int? idComentario;
  final String texto;
  final String autor;

  const DenunciaAdmin(this.id, this.motivo, this.creadoEn, this.idPublicacion, this.idComentario, this.texto, this.autor);
}

/// Todo lo que escribe el administrador. Las reglas viven en la base de datos (RLS y RPC).
class AdminRepository {
  final SupabaseClient _db;
  AdminRepository(this._db);

  Future<Map<String, dynamic>> metricas() async =>
      Map<String, dynamic>.from(await _db.rpc('metricas_admin') as Map);

  // ---- Rutas
  Future<int> guardarRuta(Map<String, dynamic> datos, {int? id}) async {
    if (id == null) {
      final r = await _db.from('ruta').insert(datos).select('id_ruta').single();
      return r['id_ruta'] as int;
    }
    await _db.from('ruta').update(datos).eq('id_ruta', id);
    return id;
  }

  Future<String> subirFoto(int idRuta, Uint8List bytes) async {
    final ruta = 'ruta_$idRuta.jpg';
    await _db.storage.from('unidades').uploadBinary(
          ruta,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final url = _db.storage.from('unidades').getPublicUrl(ruta);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<int> crearRecorrido(int idRuta, Sentido sentido) async {
    final r = await _db
        .from('recorrido')
        .insert({'id_ruta': idRuta, 'sentido': sentido.db, 'trazado': []})
        .select('id_recorrido')
        .single();
    return r['id_recorrido'] as int;
  }

  Future<void> borrarRecorrido(int idRecorrido) => _db.from('recorrido').delete().eq('id_recorrido', idRecorrido);

  Future<void> guardarRecorrido(int idRecorrido, List<LatLng> trazado, List<(int, int?)> paradas) =>
      _db.rpc('guardar_recorrido', params: {
        'p_id_recorrido': idRecorrido,
        'p_trazado': puntosAJson(trazado),
        'p_paradas': [
          for (final p in paradas) {'id_parada': p.$1, 'min_desde_inicio': p.$2},
        ],
      });

  Future<void> guardarFranjas(int idRecorrido, TipoDia tipoDia, List<Franja> franjas) =>
      _db.rpc('guardar_franjas', params: {
        'p_id_recorrido': idRecorrido,
        'p_tipo_dia': tipoDia.db,
        'p_franjas': [
          for (final f in franjas)
            {
              'hora_inicio': textoHora(f.inicio),
              'hora_fin': f.fin >= 24 * 60 ? '23:59' : textoHora(f.fin),
              'frecuencia_min': f.frecuenciaMin,
              'frecuencia_max': f.frecuenciaMax,
              'fuente': f.fuente,
            },
        ],
      });

  // ---- Paradas y lugares
  Future<void> guardarParada(Map<String, dynamic> datos, {int? id}) => id == null
      ? _db.from('parada').insert(datos)
      : _db.from('parada').update(datos).eq('id_parada', id);

  Future<void> guardarLugar(Map<String, dynamic> datos, {int? id}) => id == null
      ? _db.from('lugar').insert(datos)
      : _db.from('lugar').update(datos).eq('id_lugar', id);

  Future<void> agregarHorario(Map<String, dynamic> datos) => _db.from('horario_lugar').insert(datos);

  Future<void> borrarHorario(int id) => _db.from('horario_lugar').delete().eq('id_horario', id);

  // ---- Avisos y calendario
  Future<List<Aviso>> avisos() async {
    final filas = await _db.from('aviso_servicio').select('*, aviso_parada(id_parada)').order('creado_en', ascending: false).limit(100);
    return filas
        .map((j) => Aviso.fromJson(j, ((j['aviso_parada'] as List?) ?? const []).map((p) => (p as Map)['id_parada'] as int).toList()))
        .toList();
  }

  Future<void> guardarAviso(Map<String, dynamic> datos, List<int> paradas, {int? id}) async {
    int idAviso;
    if (id == null) {
      final r = await _db.from('aviso_servicio').insert(datos).select('id_aviso').single();
      idAviso = r['id_aviso'] as int;
    } else {
      await _db.from('aviso_servicio').update(datos).eq('id_aviso', id);
      idAviso = id;
      await _db.from('aviso_parada').delete().eq('id_aviso', id);
    }
    if (paradas.isNotEmpty) {
      await _db.from('aviso_parada').insert([for (final p in paradas) {'id_aviso': idAviso, 'id_parada': p}]);
    }
  }

  Future<void> retirarAviso(int id) => _db
      .from('aviso_servicio')
      .update({'vigente_hasta': DateTime.now().toUtc().add(const Duration(seconds: 5)).toIso8601String()})
      .eq('id_aviso', id);

  Future<void> guardarDiaEspecial(DateTime fecha, String nombre, TipoDia tipoDia, int? idAviso) =>
      _db.from('dia_especial').upsert({
        'fecha': claveFecha(fecha),
        'nombre': nombre,
        'tipo_dia_aplicado': tipoDia.db,
        'id_aviso': idAviso,
      });

  Future<void> borrarDiaEspecial(DateTime fecha) => _db.from('dia_especial').delete().eq('fecha', claveFecha(fecha));

  // ---- Moderación
  Future<List<DenunciaAdmin>> denunciasPendientes() async {
    final filas = await _db
        .from('denuncia')
        .select('id_denuncia, motivo, creado_en, id_publicacion, id_comentario, '
            'publicacion(texto, perfil:perfil!publicacion_id_usuario_fkey(nombre)), '
            'comentario(texto, perfil:perfil!comentario_id_usuario_fkey(nombre))')
        .eq('estado', 'pendiente')
        .order('creado_en');
    final vistos = <String>{};
    final res = <DenunciaAdmin>[];
    for (final j in filas) {
      final clave = '${j['id_publicacion']}-${j['id_comentario']}';
      if (!vistos.add(clave)) continue; // una tarjeta por contenido
      final contenido = (j['publicacion'] ?? j['comentario']) as Map<String, dynamic>?;
      res.add(DenunciaAdmin(
        j['id_denuncia'] as int,
        j['motivo'] as String,
        DateTime.parse(j['creado_en'] as String).toLocal(),
        j['id_publicacion'] as int?,
        j['id_comentario'] as int?,
        contenido?['texto'] as String? ?? '(sin texto)',
        (contenido?['perfil'] as Map?)?['nombre'] as String? ?? 'Usuario eliminado',
      ));
    }
    return res;
  }

  Future<int> contarDenuncias(int? idPublicacion, int? idComentario) async {
    var q = _db.from('denuncia').select('id_denuncia').eq('estado', 'pendiente');
    q = idPublicacion != null ? q.eq('id_publicacion', idPublicacion) : q.eq('id_comentario', idComentario!);
    return (await q).length;
  }

  Future<void> resolverDenuncia(int id, bool procede) =>
      _db.rpc('resolver_denuncia', params: {'p_id_denuncia': id, 'p_procede': procede});

  // ---- Usuarios y bitácora
  Future<List<UsuarioAdmin>> usuarios() async {
    final filas = await _db.rpc('admin_listar_usuarios') as List;
    return filas.cast<Map<String, dynamic>>().map(UsuarioAdmin.fromJson).toList();
  }

  Future<void> actualizarUsuario(String id, bool esAdmin, bool suspendido) => _db.rpc('admin_actualizar_usuario', params: {
        'p_id': id,
        'p_rol': esAdmin ? 'admin' : 'usuario',
        'p_estado': suspendido ? 'suspendida' : 'activa',
      });

  Future<List<Map<String, dynamic>>> bitacora() =>
      _db.from('bitacora_admin').select('*, perfil:perfil!bitacora_admin_id_admin_fkey(nombre)').order('creado_en', ascending: false).limit(200);
}
