import 'package:flutter/material.dart';

import '../../core/idioma.dart';

enum Rol { visitante, usuario, admin }

class Perfil {
  final String id;
  final String nombre;
  final Rol rol;
  final bool suspendido;
  final bool notifRutas;
  final bool notifGenerales;
  final bool notifRespuestas;
  final String idioma;

  const Perfil({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.suspendido,
    required this.notifRutas,
    required this.notifGenerales,
    required this.notifRespuestas,
    required this.idioma,
  });

  factory Perfil.fromJson(Map<String, dynamic> j) => Perfil(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        rol: j['rol'] == 'admin' ? Rol.admin : Rol.usuario,
        suspendido: j['estado'] == 'suspendida',
        notifRutas: j['notif_rutas'] as bool? ?? true,
        notifGenerales: j['notif_generales'] as bool? ?? true,
        notifRespuestas: j['notif_respuestas'] as bool? ?? true,
        idioma: j['idioma'] as String? ?? 'es',
      );

  Perfil copyWith({String? nombre, bool? notifRutas, bool? notifGenerales, bool? notifRespuestas, String? idioma}) =>
      Perfil(
        id: id,
        nombre: nombre ?? this.nombre,
        rol: rol,
        suspendido: suspendido,
        notifRutas: notifRutas ?? this.notifRutas,
        notifGenerales: notifGenerales ?? this.notifGenerales,
        notifRespuestas: notifRespuestas ?? this.notifRespuestas,
        idioma: idioma ?? this.idioma,
      );
}

enum CategoriaPublicacion {
  retraso('retraso', Icons.schedule),
  unidadLlena('unidad_llena', Icons.groups),
  desvio('desvio', Icons.alt_route),
  incidente('incidente', Icons.warning_amber),
  noPaso('no_paso', Icons.do_not_disturb_on_outlined),
  objetoPerdido('objeto_perdido', Icons.search),
  pregunta('pregunta', Icons.help_outline),
  general('general', Icons.chat_bubble_outline);

  final String db;
  final IconData icono;
  const CategoriaPublicacion(this.db, this.icono);

  static CategoriaPublicacion desdeDb(String v) =>
      CategoriaPublicacion.values.firstWhere((c) => c.db == v, orElse: () => CategoriaPublicacion.general);

  /// Reportes: urgentes, de una ruta concreta y caducan a las 6 horas.
  static const reportes = {
    CategoriaPublicacion.retraso,
    CategoriaPublicacion.unidadLlena,
    CategoriaPublicacion.desvio,
    CategoriaPublicacion.noPaso,
    CategoriaPublicacion.incidente,
  };

  /// Comunidad: conversación que dura días.
  static const comunidad = {
    CategoriaPublicacion.pregunta,
    CategoriaPublicacion.objetoPerdido,
    CategoriaPublicacion.general,
  };

  bool get esReporte => reportes.contains(this);

  /// Los reportes se muestran como "recientes" solo 6 horas.
  bool get operativa => esReporte;

  /// Texto que se manda si el usuario no escribe nada en un reporte rápido.
  String get textoPorDefecto => switch (this) {
        CategoriaPublicacion.retraso => tx('El camión viene retrasado', 'The bus is running late'),
        CategoriaPublicacion.unidadLlena => tx('La unidad va llena', 'The bus is full'),
        CategoriaPublicacion.desvio => tx('Está tomando un desvío', 'It is taking a detour'),
        CategoriaPublicacion.noPaso => tx('No ha pasado el camión', 'The bus has not come'),
        CategoriaPublicacion.incidente => tx('Hubo un incidente', 'There was an incident'),
        _ => etiqueta,
      };

  String get etiqueta => switch (this) {
        CategoriaPublicacion.retraso => tx('Retraso', 'Delay'),
        CategoriaPublicacion.unidadLlena => tx('Unidad llena', 'Bus full'),
        CategoriaPublicacion.desvio => tx('Desvío', 'Detour'),
        CategoriaPublicacion.incidente => tx('Incidente', 'Incident'),
        CategoriaPublicacion.noPaso => tx('No pasó', "Didn't come"),
        CategoriaPublicacion.objetoPerdido => tx('Objeto perdido', 'Lost item'),
        CategoriaPublicacion.pregunta => tx('Pregunta', 'Question'),
        CategoriaPublicacion.general => tx('General', 'General'),
      };
}

class Publicacion {
  final int id;
  final String? idUsuario;
  final String autor;
  final CategoriaPublicacion categoria;
  final String texto;
  final int? idRuta;
  final int? idParada;
  final bool oculta;
  final DateTime creadoEn;
  final int utiles;
  final int comentarios;
  final bool marcadaUtil;

  const Publicacion({
    required this.id,
    this.idUsuario,
    required this.autor,
    required this.categoria,
    required this.texto,
    this.idRuta,
    this.idParada,
    required this.oculta,
    required this.creadoEn,
    required this.utiles,
    required this.comentarios,
    required this.marcadaUtil,
  });

  factory Publicacion.fromJson(Map<String, dynamic> j, {String? miId}) {
    final votos = (j['voto_util'] as List?) ?? const [];
    final perfil = j['perfil'] as Map<String, dynamic>?;
    return Publicacion(
      id: j['id_publicacion'] as int,
      idUsuario: j['id_usuario'] as String?,
      autor: perfil?['nombre'] as String? ?? tx('Usuario eliminado', 'Deleted user'),
      categoria: CategoriaPublicacion.desdeDb(j['categoria'] as String),
      texto: j['texto'] as String,
      idRuta: j['id_ruta'] as int?,
      idParada: j['id_parada'] as int?,
      oculta: j['estado'] == 'oculto',
      creadoEn: DateTime.parse(j['creado_en'] as String).toLocal(),
      utiles: votos.length,
      comentarios: ((j['comentario'] as List?)?.firstOrNull as Map?)?['count'] as int? ?? 0,
      marcadaUtil: miId != null && votos.any((v) => (v as Map)['id_usuario'] == miId),
    );
  }

  bool get reciente => !categoria.operativa || DateTime.now().difference(creadoEn).inHours < 6;
}

class Comentario {
  final int id;
  final String? idUsuario;
  final String autor;
  final String texto;
  final DateTime creadoEn;

  const Comentario({required this.id, this.idUsuario, required this.autor, required this.texto, required this.creadoEn});

  factory Comentario.fromJson(Map<String, dynamic> j) => Comentario(
        id: j['id_comentario'] as int,
        idUsuario: j['id_usuario'] as String?,
        autor: (j['perfil'] as Map<String, dynamic>?)?['nombre'] as String? ?? tx('Usuario eliminado', 'Deleted user'),
        texto: j['texto'] as String,
        creadoEn: DateTime.parse(j['creado_en'] as String).toLocal(),
      );
}
