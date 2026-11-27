import 'package:latlong2/latlong.dart';

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/idioma.dart';
import '../../core/tiempo.dart';
import '../catalogo.dart';
import '../entities/transporte.dart';
import '../entities/viaje.dart';
import 'hora_pico.dart';

/// Planificador de viaje. Corre en el teléfono con el catálogo guardado,
/// así que funciona aunque no haya internet.
///
/// Busca viajes directos o con un transbordo. Como en Dolores el camión se para
/// donde le hacen la mano, el punto de abordaje es el punto del recorrido más
/// cercano a ti, no solo una parada registrada.
///
/// Tiempo total como rango:
///   mínimo = caminata + trayecto
///   máximo = mínimo + frecuencia máxima de cada camión (la peor espera posible)
class Planificador {
  final Catalogo cat;
  const Planificador(this.cat);

  ResultadoPlan planear(PuntoNombrado origen, PuntoNombrado destino, DateTime momento) {
    final directo = distanciaM(origen.punto, destino.punto);
    final opcionPie = _soloCaminando(origen, destino, directo);

    if (directo < 300) {
      return ResultadoPlan([opcionPie], tx('Está muy cerca: te conviene caminar.', "It's very close: walking is best."));
    }

    final cercaOrigen = <(RecorridoGeo, Proyeccion)>[];
    final cercaDestino = <RecorridoGeo, Proyeccion>{};
    int? proximoInicio;
    var huboFueraDeServicio = false;

    for (final g in cat.geosActivos) {
      final pd = g.linea.proyectar(destino.punto);
      final po = g.linea.proyectar(origen.punto);
      final estado = cat.estadoRecorrido(g.recorrido.id, momento);
      final cerca = po.distancia <= Config.radioAbordaje || pd.distancia <= Config.radioAbordaje;
      if (!estado.enServicio) {
        if (cerca) {
          huboFueraDeServicio = true;
          if (estado.proximoInicio != null && (proximoInicio == null || estado.proximoInicio! < proximoInicio)) {
            proximoInicio = estado.proximoInicio;
          }
        }
        continue;
      }
      if (po.distancia <= Config.radioAbordaje) cercaOrigen.add((g, po));
      if (pd.distancia <= Config.radioAbordaje) cercaDestino[g] = pd;
    }

    final opciones = <OpcionViaje>[];

    // 1) Directos
    for (final (g, po) in cercaOrigen) {
      final pd = cercaDestino[g];
      if (pd == null) continue;
      final opcion = _directa(g, po, pd, origen, destino, momento);
      if (opcion != null) opciones.add(opcion);
    }

    // 2) Con un transbordo (solo si no hay directos)
    if (opciones.isEmpty) {
      for (final (ga, poA) in cercaOrigen) {
        for (final entrada in cercaDestino.entries) {
          final gb = entrada.key;
          if (gb.ruta.id == ga.ruta.id) continue;
          final opcion = _conTransbordo(ga, poA, gb, entrada.value, origen, destino, momento);
          if (opcion != null) opciones.add(opcion);
        }
      }
    }

    // Una opción por combinación de rutas (la mejor)
    final unicas = <String, OpcionViaje>{};
    for (final o in opciones) {
      final clave = o.enCamion.map((t) => t.recorrido!.id).join('-');
      final previa = unicas[clave];
      if (previa == null || o.maxMinutos < previa.maxMinutos) unicas[clave] = o;
    }
    final ordenadas = unicas.values.toList()
      ..sort((a, b) {
        final t = a.transbordos.compareTo(b.transbordos);
        if (t != 0) return t;
        final c = a.metrosCaminando.compareTo(b.metrosCaminando);
        if (c.abs() > 150) return c;
        return a.maxMinutos.compareTo(b.maxMinutos);
      });
    final mejores = ordenadas.take(3).toList();

    if (mejores.isEmpty) {
      if (directo <= 3000) {
        final msg = huboFueraDeServicio
            ? _mensajeFueraDeServicio(proximoInicio)
            : tx('Ninguna ruta pasa a menos de 600 m. Puedes llegar caminando.',
                'No route passes within 600 m. You can walk there.');
        return ResultadoPlan([opcionPie], msg);
      }
      return ResultadoPlan(
        const [],
        huboFueraDeServicio
            ? _mensajeFueraDeServicio(proximoInicio)
            : tx('Ninguna ruta pasa a menos de 600 m de tu origen y tu destino con un transbordo como máximo.',
                'No route passes within 600 m of your origin and destination with at most one transfer.'),
      );
    }

    // Comparar contra caminar
    if (opcionPie.maxMinutos <= mejores.first.maxMinutos + 5) {
      mejores.add(opcionPie);
    }
    return ResultadoPlan(mejores);
  }

  String _mensajeFueraDeServicio(int? inicio) => inicio == null
      ? tx('Las rutas cercanas ya no tienen servicio hoy.', 'Nearby routes have no more service today.')
      : tx('Fuera de servicio a esa hora. El primero inicia a las ${textoHora(inicio)}.',
          'Out of service at that time. First bus starts at ${textoHora(inicio)}.');

  OpcionViaje _soloCaminando(PuntoNombrado o, PuntoNombrado d, double metros) {
    final m = minutosCaminando(metros);
    return OpcionViaje(
      tramos: [_caminar(o.punto, d.punto, o.nombre, d.nombre)],
      minMinutos: m,
      maxMinutos: m,
      soloCaminando: true,
    );
  }

  Tramo _caminar(LatLng a, LatLng b, String na, String nb) {
    final metros = distanciaM(a, b);
    return Tramo(
      tipo: TipoTramo.caminar,
      desde: a,
      hasta: b,
      desdeNombre: na,
      hastaNombre: nb,
      minutos: minutosCaminando(metros),
      metros: metros * Config.factorCalles,
    );
  }

  String _nombrePunto(RecorridoGeo g, double avance, double distanciaAlPunto) {
    final cercana = g.paradaCercana(avance);
    if (cercana != null) return cercana.$1.nombre;
    return tx('Sobre el recorrido de la ${g.ruta.nombre}', 'Along ${g.ruta.nombre}');
  }

  Tramo _enCamion(RecorridoGeo g, double sube, double baja, int minutos, DateTime momento) {
    final estado = cat.estadoRecorrido(g.recorrido.id, momento);
    return Tramo(
      tipo: TipoTramo.camion,
      desde: g.linea.puntoEn(sube),
      hasta: g.linea.puntoEn(baja),
      desdeNombre: _nombrePunto(g, sube, 0),
      hastaNombre: _nombrePunto(g, baja, 0),
      minutos: minutos,
      metros: baja >= sube ? baja - sube : g.linea.largo - sube + baja,
      ruta: g.ruta,
      recorrido: g.recorrido,
      avanceSube: sube,
      avanceBaja: baja,
      frecuenciaMin: estado.frecuenciaMin,
      frecuenciaMax: estado.frecuenciaMax,
      paradasIntermedias: g.paradasEntre(sube, baja),
      minutosEstimados: !g.tieneMinutos,
    );
  }

  OpcionViaje? _directa(RecorridoGeo g, Proyeccion po, Proyeccion pd, PuntoNombrado o, PuntoNombrado d, DateTime momento) {
    final viaje = g.minutosEntre(po.avance, pd.avance);
    if (viaje == null) return null;
    final bus = _enCamion(g, po.avance, pd.avance, viaje, momento);
    final pie1 = _caminar(o.punto, po.punto, o.nombre, bus.desdeNombre);
    final pie2 = _caminar(pd.punto, d.punto, bus.hastaNombre, d.nombre);
    final minimo = pie1.minutos + viaje + pie2.minutos;
    return OpcionViaje(
      tramos: [pie1, bus, pie2],
      minMinutos: minimo,
      maxMinutos: minimo + (bus.frecuenciaMax ?? 0),
      avisosDemanda: _demanda([g.ruta], momento),
      avisosVigentes: cat.avisosVigentes(momento, idRuta: g.ruta.id),
    );
  }

  OpcionViaje? _conTransbordo(RecorridoGeo ga, Proyeccion poA, RecorridoGeo gb, Proyeccion pdB, PuntoNombrado o,
      PuntoNombrado d, DateTime momento) {
    const paso = 40.0;
    double? mejorCosto;
    (double, Proyeccion, int, int)? mejor; // (avance en A, proyección en B, min A, min B)

    final fin = ga.linea.largo;
    for (var av = poA.avance + paso; av <= fin; av += paso) {
      final punto = ga.linea.puntoEn(av);
      final enB = gb.linea.proyectar(punto);
      if (enB.distancia > Config.radioTransbordo) continue;
      final minA = ga.minutosEntre(poA.avance, av);
      final minB = gb.minutosEntre(enB.avance, pdB.avance);
      if (minA == null || minB == null) continue;
      final costo = minA + minutosCaminando(enB.distancia) + minB;
      if (mejorCosto == null || costo < mejorCosto) {
        mejorCosto = costo.toDouble();
        mejor = (av, enB, minA, minB);
      }
    }
    if (mejor == null) return null;

    final (avA, enB, minA, minB) = mejor;
    final busA = _enCamion(ga, poA.avance, avA, minA, momento);
    final busB = _enCamion(gb, enB.avance, pdB.avance, minB, momento);
    final pie1 = _caminar(o.punto, poA.punto, o.nombre, busA.desdeNombre);
    final cambio = _caminar(ga.linea.puntoEn(avA), enB.punto, busA.hastaNombre, busB.desdeNombre);
    final pie2 = _caminar(pdB.punto, d.punto, busB.hastaNombre, d.nombre);
    final minimo = pie1.minutos + minA + cambio.minutos + minB + pie2.minutos;
    return OpcionViaje(
      tramos: [pie1, busA, cambio, busB, pie2],
      minMinutos: minimo,
      maxMinutos: minimo + (busA.frecuenciaMax ?? 0) + (busB.frecuenciaMax ?? 0),
      avisosDemanda: _demanda([ga.ruta, gb.ruta], momento),
      avisosVigentes: [
        ...cat.avisosVigentes(momento, idRuta: ga.ruta.id),
        ...cat.avisosVigentes(momento, idRuta: gb.ruta.id, incluirGenerales: false),
      ],
    );
  }

  List<String> _demanda(List<Ruta> rutas, DateTime momento) {
    final textos = <String>[];
    for (final r in rutas) {
      final eventos = demandaCerca(cat, r.id, momento);
      if (eventos.isEmpty) continue;
      final porHora = <int, List<EventoDemanda>>{};
      for (final e in eventos) {
        porHora.putIfAbsent(e.hora, () => []).add(e);
      }
      for (final h in porHora.entries) {
        final nombres = h.value.map((e) => e.lugar.nombre).toSet().join(', ');
        textos.add(tx(
          'A las ${textoHora(h.key)} hay ${h.value.first.horario.evento.etiqueta.toLowerCase()} en $nombres, sobre la ${r.nombre}.',
          'At ${textoHora(h.key)}: ${h.value.first.horario.evento.etiqueta.toLowerCase()} at $nombres, along ${r.nombre}.',
        ));
      }
    }
    return textos;
  }
}
