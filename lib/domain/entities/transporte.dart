import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';
import '../../core/idioma.dart';
import '../../core/tiempo.dart';

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();

class Ruta {
  final int id;
  final String nombre;
  final String color;
  final double tarifa;
  final double? tarifaEstudiante;
  final double? tarifaInapam;
  final String? fuenteTarifas;
  final String? letrero;
  final String? descripcionUnidad;
  final String? fotoUnidad;
  final String? concesionario;
  final bool activa;
  final DateTime revisadaEn;

  const Ruta({
    required this.id,
    required this.nombre,
    required this.color,
    required this.tarifa,
    this.tarifaEstudiante,
    this.tarifaInapam,
    this.fuenteTarifas,
    this.letrero,
    this.descripcionUnidad,
    this.fotoUnidad,
    this.concesionario,
    required this.activa,
    required this.revisadaEn,
  });

  factory Ruta.fromJson(Map<String, dynamic> j) => Ruta(
        id: j['id_ruta'] as int,
        nombre: j['nombre'] as String,
        color: (j['color'] as String).trim(),
        tarifa: _d(j['tarifa']),
        tarifaEstudiante: _dn(j['tarifa_estudiante']),
        tarifaInapam: _dn(j['tarifa_inapam']),
        fuenteTarifas: j['fuente_tarifas'] as String?,
        letrero: j['letrero'] as String?,
        descripcionUnidad: j['descripcion_unidad'] as String?,
        fotoUnidad: j['foto_unidad'] as String?,
        concesionario: j['concesionario'] as String?,
        activa: j['activa'] as bool? ?? false,
        revisadaEn: DateTime.tryParse(j['revisada_en']?.toString() ?? '') ?? DateTime.now(),
      );
}

enum Sentido {
  ida('ida'),
  vuelta('vuelta'),
  circuito('circuito');

  final String db;
  const Sentido(this.db);
  static Sentido desdeDb(String v) => Sentido.values.firstWhere((s) => s.db == v, orElse: () => Sentido.ida);

  String get etiqueta => switch (this) {
        Sentido.ida => tx('Ida', 'Outbound'),
        Sentido.vuelta => tx('Vuelta', 'Return'),
        Sentido.circuito => tx('Circuito', 'Loop'),
      };
}

class ParadaEnRecorrido {
  final int idParada;
  final int orden;
  final int? minDesdeInicio;

  const ParadaEnRecorrido(this.idParada, this.orden, this.minDesdeInicio);

  factory ParadaEnRecorrido.fromJson(Map<String, dynamic> j) => ParadaEnRecorrido(
        j['id_parada'] as int,
        j['orden'] as int,
        j['min_desde_inicio'] as int?,
      );
}

class Recorrido {
  final int id;
  final int idRuta;
  final Sentido sentido;
  final List<LatLng> trazado;
  final List<ParadaEnRecorrido> paradas;

  const Recorrido({
    required this.id,
    required this.idRuta,
    required this.sentido,
    required this.trazado,
    required this.paradas,
  });

  factory Recorrido.fromJson(Map<String, dynamic> j, List<ParadaEnRecorrido> paradas) => Recorrido(
        id: j['id_recorrido'] as int,
        idRuta: j['id_ruta'] as int,
        sentido: Sentido.desdeDb(j['sentido'] as String),
        trazado: puntosDesdeJson(j['trazado']),
        paradas: paradas..sort((a, b) => a.orden.compareTo(b.orden)),
      );
}

class Franja {
  final int id;
  final int idRecorrido;
  final TipoDia tipoDia;
  final int inicio; // minutos desde medianoche
  final int fin;
  final int frecuenciaMin;
  final int frecuenciaMax;
  final String fuente;

  const Franja({
    required this.id,
    required this.idRecorrido,
    required this.tipoDia,
    required this.inicio,
    required this.fin,
    required this.frecuenciaMin,
    required this.frecuenciaMax,
    required this.fuente,
  });

  factory Franja.fromJson(Map<String, dynamic> j) => Franja(
        id: j['id_franja'] as int,
        idRecorrido: j['id_recorrido'] as int,
        tipoDia: TipoDia.desdeDb(j['tipo_dia'] as String),
        inicio: minutosDesdeTexto(j['hora_inicio'] as String),
        fin: minutosDesdeTexto(j['hora_fin'] as String),
        frecuenciaMin: j['frecuencia_min'] as int,
        frecuenciaMax: j['frecuencia_max'] as int,
        fuente: j['fuente'] as String? ?? 'levantamiento',
      );

  bool contiene(int minuto) => minuto >= inicio && minuto < fin;
}

class Parada {
  final int id;
  final String nombre;
  final String? referencia;
  final LatLng punto;
  final bool activa;

  const Parada({required this.id, required this.nombre, this.referencia, required this.punto, required this.activa});

  factory Parada.fromJson(Map<String, dynamic> j) => Parada(
        id: j['id_parada'] as int,
        nombre: j['nombre'] as String,
        referencia: j['referencia'] as String?,
        punto: LatLng(_d(j['latitud']), _d(j['longitud'])),
        activa: j['activa'] as bool? ?? true,
      );
}

enum CategoriaLugar {
  educacion('educacion'),
  trabajo('trabajo'),
  salud('salud'),
  gobierno('gobierno'),
  turismo('turismo'),
  comercio('comercio'),
  transporte('transporte');

  final String db;
  const CategoriaLugar(this.db);
  static CategoriaLugar desdeDb(String v) =>
      CategoriaLugar.values.firstWhere((c) => c.db == v, orElse: () => CategoriaLugar.comercio);

  String get etiqueta => switch (this) {
        CategoriaLugar.educacion => tx('Educación', 'Education'),
        CategoriaLugar.trabajo => tx('Trabajo', 'Work'),
        CategoriaLugar.salud => tx('Salud', 'Health'),
        CategoriaLugar.gobierno => tx('Gobierno', 'Government'),
        CategoriaLugar.turismo => tx('Turismo', 'Tourism'),
        CategoriaLugar.comercio => tx('Comercio', 'Shopping'),
        CategoriaLugar.transporte => tx('Transporte', 'Transport'),
      };
}

class Lugar {
  final int id;
  final String nombre;
  final CategoriaLugar categoria;
  final LatLng punto;
  final bool activo;

  const Lugar({required this.id, required this.nombre, required this.categoria, required this.punto, required this.activo});

  factory Lugar.fromJson(Map<String, dynamic> j) => Lugar(
        id: j['id_lugar'] as int,
        nombre: j['nombre'] as String,
        categoria: CategoriaLugar.desdeDb(j['categoria'] as String),
        punto: LatLng(_d(j['latitud']), _d(j['longitud'])),
        activo: j['activo'] as bool? ?? true,
      );
}

enum TipoEvento {
  entrada('entrada'),
  salida('salida'),
  cambioTurno('cambio_turno'),
  tianguis('tianguis'),
  otro('otro');

  final String db;
  const TipoEvento(this.db);
  static TipoEvento desdeDb(String v) => TipoEvento.values.firstWhere((e) => e.db == v, orElse: () => TipoEvento.otro);

  String get etiqueta => switch (this) {
        TipoEvento.entrada => tx('Entrada', 'Start'),
        TipoEvento.salida => tx('Salida', 'End'),
        TipoEvento.cambioTurno => tx('Cambio de turno', 'Shift change'),
        TipoEvento.tianguis => tx('Tianguis', 'Street market'),
        TipoEvento.otro => tx('Evento', 'Event'),
      };
}

class HorarioLugar {
  final int id;
  final int idLugar;
  final TipoDia tipoDia;
  final int? diaSemana;
  final int hora;
  final TipoEvento evento;
  final String? descripcion;
  final String fuente;

  const HorarioLugar({
    required this.id,
    required this.idLugar,
    required this.tipoDia,
    this.diaSemana,
    required this.hora,
    required this.evento,
    this.descripcion,
    required this.fuente,
  });

  factory HorarioLugar.fromJson(Map<String, dynamic> j) => HorarioLugar(
        id: j['id_horario'] as int,
        idLugar: j['id_lugar'] as int,
        tipoDia: TipoDia.desdeDb(j['tipo_dia'] as String),
        diaSemana: j['dia_semana'] as int?,
        hora: minutosDesdeTexto(j['hora'] as String),
        evento: TipoEvento.desdeDb(j['evento'] as String),
        descripcion: j['descripcion'] as String?,
        fuente: j['fuente'] as String,
      );
}

enum TipoAviso {
  desvio('desvio'),
  suspension('suspension'),
  cambioHorario('cambio_horario'),
  cambioRecorrido('cambio_recorrido'),
  paradaCerrada('parada_cerrada'),
  general('general');

  final String db;
  const TipoAviso(this.db);
  static TipoAviso desdeDb(String v) => TipoAviso.values.firstWhere((t) => t.db == v, orElse: () => TipoAviso.general);

  String get etiqueta => switch (this) {
        TipoAviso.desvio => tx('Desvío', 'Detour'),
        TipoAviso.suspension => tx('Suspensión', 'Suspended'),
        TipoAviso.cambioHorario => tx('Cambio de horario', 'Schedule change'),
        TipoAviso.cambioRecorrido => tx('Cambio de recorrido', 'Route change'),
        TipoAviso.paradaCerrada => tx('Parada cerrada', 'Stop closed'),
        TipoAviso.general => tx('Aviso general', 'General notice'),
      };
}

class Aviso {
  final int id;
  final int? idRuta;
  final TipoAviso tipo;
  final String titulo;
  final String detalle;
  final DateTime vigenteDesde;
  final DateTime? vigenteHasta;
  final bool automatico;
  final DateTime creadoEn;
  final List<int> paradasAfectadas;

  const Aviso({
    required this.id,
    this.idRuta,
    required this.tipo,
    required this.titulo,
    required this.detalle,
    required this.vigenteDesde,
    this.vigenteHasta,
    required this.automatico,
    required this.creadoEn,
    this.paradasAfectadas = const [],
  });

  factory Aviso.fromJson(Map<String, dynamic> j, [List<int> paradas = const []]) => Aviso(
        id: j['id_aviso'] as int,
        idRuta: j['id_ruta'] as int?,
        tipo: TipoAviso.desdeDb(j['tipo'] as String),
        titulo: j['titulo'] as String,
        detalle: j['detalle'] as String? ?? '',
        vigenteDesde: DateTime.parse(j['vigente_desde'] as String).toLocal(),
        vigenteHasta: j['vigente_hasta'] == null ? null : DateTime.parse(j['vigente_hasta'] as String).toLocal(),
        automatico: j['automatico'] as bool? ?? false,
        creadoEn: DateTime.parse(j['creado_en'] as String).toLocal(),
        paradasAfectadas: paradas,
      );

  bool vigenteEn(DateTime t) => !t.isBefore(vigenteDesde) && (vigenteHasta == null || t.isBefore(vigenteHasta!));
}

class DiaEspecial {
  final DateTime fecha;
  final String nombre;
  final TipoDia tipoDia;
  final int? idAviso;

  const DiaEspecial({required this.fecha, required this.nombre, required this.tipoDia, this.idAviso});

  factory DiaEspecial.fromJson(Map<String, dynamic> j) => DiaEspecial(
        fecha: DateTime.parse(j['fecha'] as String),
        nombre: j['nombre'] as String,
        tipoDia: TipoDia.desdeDb(j['tipo_dia_aplicado'] as String),
        idAviso: j['id_aviso'] as int?,
      );
}

String etiquetaFuente(String f) => switch (f) {
      'oficial' => tx('Oficial', 'Official'),
      'concesionario' => tx('Concesionario', 'Operator'),
      'municipio' => tx('Municipio', 'Municipality'),
      'institucion' => tx('La institución', 'The institution'),
      _ => tx('Levantamiento en campo', 'Field survey'),
    };
