import '../../core/config.dart';
import '../../core/tiempo.dart';
import '../catalogo.dart';
import '../entities/transporte.dart';

/// Un hecho de alta demanda: "7:00 · entrada · UTNG".
class EventoDemanda {
  final int hora;
  final Lugar lugar;
  final HorarioLugar horario;
  const EventoDemanda(this.hora, this.lugar, this.horario);
}

/// Horarios de alta demanda de una ruta: entradas, salidas y turnos
/// de los lugares a menos de 400 m de su recorrido. Son hechos con fuente, no estimaciones.
List<EventoDemanda> horaPicoDeRuta(Catalogo cat, int idRuta, TipoDia tipoDia, {int? diaSemana}) {
  final geos = cat.geosDeRuta(idRuta).where((g) => g.usable).toList();
  if (geos.isEmpty) return [];

  final cercanos = <int, Lugar>{};
  for (final l in cat.lugaresActivos) {
    for (final g in geos) {
      if (g.linea.proyectar(l.punto).distancia <= Config.radioLugarDemanda) {
        cercanos[l.id] = l;
        break;
      }
    }
  }

  final eventos = <EventoDemanda>[];
  for (final h in cat.horarios) {
    final lugar = cercanos[h.idLugar];
    if (lugar == null || h.tipoDia != tipoDia) continue;
    if (h.diaSemana != null && diaSemana != null && h.diaSemana != diaSemana) continue;
    eventos.add(EventoDemanda(h.hora, lugar, h));
  }
  eventos.sort((a, b) => a.hora.compareTo(b.hora));
  return eventos;
}

/// Eventos de alta demanda dentro de ±[margen] minutos de un momento.
List<EventoDemanda> demandaCerca(Catalogo cat, int idRuta, DateTime momento, {int margen = 30}) {
  final m = minutosDelDia(momento);
  return horaPicoDeRuta(cat, idRuta, cat.tipoDia(momento), diaSemana: momento.weekday)
      .where((e) => (e.hora - m).abs() <= margen)
      .toList();
}
