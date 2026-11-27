import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/tiempo.dart';
import 'entities/transporte.dart';

/// Recorrido listo para cálculos: línea proyectable y paradas ubicadas sobre ella.
class RecorridoGeo {
  final Recorrido recorrido;
  final Ruta ruta;
  final Linea linea;

  /// (parada, avance en metros sobre la línea, minutos medidos)
  final List<(Parada, double, int?)> paradas;

  RecorridoGeo(this.recorrido, this.ruta, this.linea, this.paradas);

  bool get usable => linea.valida;

  bool get tieneMinutos => paradas.where((p) => p.$3 != null).length >= 2;

  /// Minutos desde la terminal en un punto de la línea, interpolando entre paradas medidas.
  /// Si no hay al menos dos paradas con minutos, usa 15 km/h (250 m/min) y se marca como estimado.
  double minutosEn(double avance) {
    final medidas = paradas.where((p) => p.$3 != null).toList()..sort((a, b) => a.$2.compareTo(b.$2));
    if (medidas.length < 2) return avance / 250.0;
    if (avance <= medidas.first.$2) {
      final r = _ritmo(medidas[0], medidas[1]);
      return (medidas.first.$3!.toDouble() - (medidas.first.$2 - avance) * r).clamp(0.0, double.infinity);
    }
    for (var i = 1; i < medidas.length; i++) {
      final a = medidas[i - 1], b = medidas[i];
      if (avance <= b.$2) {
        final t = b.$2 == a.$2 ? 0.0 : (avance - a.$2) / (b.$2 - a.$2);
        return a.$3! + t * (b.$3! - a.$3!);
      }
    }
    final ult = medidas.last, pen = medidas[medidas.length - 2];
    return ult.$3! + (avance - ult.$2) * _ritmo(pen, ult);
  }

  double _ritmo((Parada, double, int?) a, (Parada, double, int?) b) {
    final metros = (b.$2 - a.$2).abs();
    return metros == 0 ? 1 / 250.0 : ((b.$3! - a.$3!).abs() / metros);
  }

  /// Minutos de viaje entre dos avances. En circuitos se permite dar la vuelta.
  int? minutosEntre(double sube, double baja) {
    if (baja > sube) return (minutosEn(baja) - minutosEn(sube)).ceil().clamp(1, 600);
    if (recorrido.sentido == Sentido.circuito) {
      final total = minutosEn(linea.largo) - minutosEn(sube) + minutosEn(baja) - minutosEn(0);
      return total.ceil().clamp(1, 600);
    }
    return null;
  }

  int paradasEntre(double sube, double baja) {
    if (baja > sube) return paradas.where((p) => p.$2 > sube && p.$2 < baja).length;
    return paradas.where((p) => p.$2 > sube || p.$2 < baja).length;
  }

  /// Parada registrada más cercana a un avance (para dar referencias).
  (Parada, double)? paradaCercana(double avance, {double maxMetros = 100}) {
    (Parada, double)? mejor;
    for (final p in paradas) {
      final d = (p.$2 - avance).abs();
      if (d <= maxMetros && (mejor == null || d < mejor.$2)) mejor = (p.$1, d);
    }
    return mejor;
  }
}

/// Estado del servicio de una ruta o recorrido en un momento.
class EstadoServicio {
  final bool enServicio;
  final int? frecuenciaMin;
  final int? frecuenciaMax;
  final int? hasta; // fin de la franja actual
  final int? proximoInicio; // si está fuera de servicio y aún inicia hoy
  final int? ultimoServicio; // fin del servicio del día
  final int? inicioManana; // si ya terminó por hoy: a qué hora inicia mañana

  const EstadoServicio({
    required this.enServicio,
    this.frecuenciaMin,
    this.frecuenciaMax,
    this.hasta,
    this.proximoInicio,
    this.ultimoServicio,
    this.inicioManana,
  });

  static const sinServicio = EstadoServicio(enServicio: false);
}

/// Todo el catálogo del transporte en memoria, con índices y cálculos comunes.
class Catalogo {
  final List<Ruta> rutas;
  final List<Recorrido> recorridos;
  final List<Parada> paradas;
  final List<Franja> franjas;
  final List<Lugar> lugares;
  final List<HorarioLugar> horarios;
  final List<Aviso> avisos;
  final List<DiaEspecial> diasEspeciales;
  final DateTime actualizado;

  late final Map<int, Ruta> rutaPorId = {for (final r in rutas) r.id: r};
  late final Map<int, Parada> paradaPorId = {for (final p in paradas) p.id: p};
  late final Map<int, Lugar> lugarPorId = {for (final l in lugares) l.id: l};
  late final Map<String, TipoDia> especiales = {for (final d in diasEspeciales) claveFecha(d.fecha): d.tipoDia};

  late final List<RecorridoGeo> geos = [
    for (final rec in recorridos)
      if (rutaPorId[rec.idRuta] != null) _armarGeo(rec, rutaPorId[rec.idRuta]!),
  ];

  Catalogo({
    required this.rutas,
    required this.recorridos,
    required this.paradas,
    required this.franjas,
    required this.lugares,
    required this.horarios,
    required this.avisos,
    required this.diasEspeciales,
    required this.actualizado,
  });

  factory Catalogo.vacio() => Catalogo(
        rutas: const [],
        recorridos: const [],
        paradas: const [],
        franjas: const [],
        lugares: const [],
        horarios: const [],
        avisos: const [],
        diasEspeciales: const [],
        actualizado: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get vacio => rutas.isEmpty;

  RecorridoGeo _armarGeo(Recorrido rec, Ruta ruta) {
    final linea = Linea(rec.trazado);
    final ubicadas = <(Parada, double, int?)>[];
    for (final pr in rec.paradas) {
      final p = paradaPorId[pr.idParada];
      if (p == null) continue;
      ubicadas.add((p, linea.proyectar(p.punto).avance, pr.minDesdeInicio));
    }
    return RecorridoGeo(rec, ruta, linea, ubicadas);
  }

  List<Ruta> get rutasActivas => rutas.where((r) => r.activa).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
  List<Parada> get paradasActivas => paradas.where((p) => p.activa).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
  List<Lugar> get lugaresActivos => lugares.where((l) => l.activo).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));

  List<RecorridoGeo> geosDeRuta(int idRuta) =>
      geos.where((g) => g.ruta.id == idRuta).toList()..sort((a, b) => a.recorrido.sentido.index.compareTo(b.recorrido.sentido.index));

  List<RecorridoGeo> get geosActivos => geos.where((g) => g.ruta.activa && g.usable).toList();

  TipoDia tipoDia(DateTime t) => tipoDiaPara(t, especiales);

  DiaEspecial? diaEspecial(DateTime t) {
    final c = claveFecha(t);
    for (final d in diasEspeciales) {
      if (claveFecha(d.fecha) == c) return d;
    }
    return null;
  }

  List<Franja> franjasDe(int idRecorrido, TipoDia td) =>
      franjas.where((f) => f.idRecorrido == idRecorrido && f.tipoDia == td).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));

  EstadoServicio estadoRecorrido(int idRecorrido, DateTime t) {
    final lista = franjasDe(idRecorrido, tipoDia(t));
    if (lista.isEmpty) return EstadoServicio(enServicio: false, inicioManana: _inicioManana(idRecorrido, t));
    final m = minutosDelDia(t);
    final ultimo = lista.map((f) => f.fin).reduce((a, b) => a > b ? a : b);
    for (final f in lista) {
      if (f.contiene(m)) {
        return EstadoServicio(
          enServicio: true,
          frecuenciaMin: f.frecuenciaMin,
          frecuenciaMax: f.frecuenciaMax,
          hasta: f.fin,
          ultimoServicio: ultimo,
        );
      }
    }
    final siguientes = lista.where((f) => f.inicio > m).toList();
    return EstadoServicio(
      enServicio: false,
      proximoInicio: siguientes.isEmpty ? null : siguientes.first.inicio,
      ultimoServicio: ultimo,
      inicioManana: siguientes.isEmpty ? _inicioManana(idRecorrido, t) : null,
    );
  }

  int? _inicioManana(int idRecorrido, DateTime t) {
    final manana = DateTime(t.year, t.month, t.day).add(const Duration(days: 1));
    final lista = franjasDe(idRecorrido, tipoDia(manana));
    return lista.isEmpty ? null : lista.first.inicio;
  }

  EstadoServicio estadoRuta(int idRuta, DateTime t) {
    final estados = geosDeRuta(idRuta).map((g) => estadoRecorrido(g.recorrido.id, t)).toList();
    if (estados.isEmpty) return EstadoServicio.sinServicio;
    final activos = estados.where((e) => e.enServicio).toList();
    final ultimos = estados.map((e) => e.ultimoServicio).whereType<int>();
    final ultimo = ultimos.isEmpty ? null : ultimos.reduce((a, b) => a > b ? a : b);
    if (activos.isNotEmpty) {
      return EstadoServicio(
        enServicio: true,
        frecuenciaMin: activos.map((e) => e.frecuenciaMin!).reduce((a, b) => a < b ? a : b),
        frecuenciaMax: activos.map((e) => e.frecuenciaMax!).reduce((a, b) => a > b ? a : b),
        hasta: activos.map((e) => e.hasta!).reduce((a, b) => a > b ? a : b),
        ultimoServicio: ultimo,
      );
    }
    final proximos = estados.map((e) => e.proximoInicio).whereType<int>();
    final mananas = estados.map((e) => e.inicioManana).whereType<int>();
    return EstadoServicio(
      enServicio: false,
      proximoInicio: proximos.isEmpty ? null : proximos.reduce((a, b) => a < b ? a : b),
      ultimoServicio: ultimo,
      inicioManana: proximos.isNotEmpty || mananas.isEmpty ? null : mananas.reduce((a, b) => a < b ? a : b),
    );
  }

  List<Aviso> avisosVigentes(DateTime t, {int? idRuta, bool incluirGenerales = true}) => avisos
      .where((a) => a.vigenteEn(t))
      .where((a) => idRuta == null || a.idRuta == idRuta || (incluirGenerales && a.idRuta == null))
      .toList()
    ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

  /// Rutas cuyo trazado pasa a menos de [radio] metros de un punto.
  List<(RecorridoGeo, Proyeccion)> recorridosCerca(LatLng p, double radio) {
    final res = <(RecorridoGeo, Proyeccion)>[];
    for (final g in geosActivos) {
      final pr = g.linea.proyectar(p);
      if (pr.distancia <= radio) res.add((g, pr));
    }
    res.sort((a, b) => a.$2.distancia.compareTo(b.$2.distancia));
    return res;
  }

  List<(Parada, double)> paradasCerca(LatLng p, double radio) {
    final res = <(Parada, double)>[];
    for (final par in paradasActivas) {
      final d = distanciaM(p, par.punto);
      if (d <= radio) res.add((par, d));
    }
    res.sort((a, b) => a.$2.compareTo(b.$2));
    return res;
  }

  /// Rutas que pasan por una parada (según los recorridos capturados).
  List<(Ruta, Recorrido)> rutasDeParada(int idParada) => [
        for (final g in geosActivos)
          if (g.recorrido.paradas.any((p) => p.idParada == idParada)) (g.ruta, g.recorrido),
      ];
}
