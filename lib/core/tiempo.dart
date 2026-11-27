import 'idioma.dart';

/// Tipo de día de servicio (igual que el enum tipo_dia de la base de datos).
enum TipoDia {
  laborable('laborable'),
  sabado('sabado'),
  domingoFestivo('domingo_festivo');

  final String db;
  const TipoDia(this.db);

  static TipoDia desdeDb(String v) =>
      TipoDia.values.firstWhere((t) => t.db == v, orElse: () => TipoDia.laborable);

  String get etiqueta => switch (this) {
        TipoDia.laborable => tx('Lunes a viernes', 'Weekdays'),
        TipoDia.sabado => tx('Sábado', 'Saturday'),
        TipoDia.domingoFestivo => tx('Domingo y festivos', 'Sunday & holidays'),
      };
}

/// Clave de fecha "2026-12-25"
String claveFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Tipo de día que aplica en una fecha, considerando el calendario de días especiales.
TipoDia tipoDiaPara(DateTime fecha, Map<String, TipoDia> especiales) {
  final especial = especiales[claveFecha(fecha)];
  if (especial != null) return especial;
  if (fecha.weekday == DateTime.saturday) return TipoDia.sabado;
  if (fecha.weekday == DateTime.sunday) return TipoDia.domingoFestivo;
  return TipoDia.laborable;
}

/// "07:30:00" o "07:30" → minutos desde medianoche
int minutosDesdeTexto(String hora) {
  final partes = hora.split(':');
  return int.parse(partes[0]) * 60 + int.parse(partes.length > 1 ? partes[1] : '0');
}

/// minutos desde medianoche → "07:30"
String textoHora(int minutos) {
  final m = minutos % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

int minutosDelDia(DateTime d) => d.hour * 60 + d.minute;

/// "18–30 min" o "18 min"
String rangoMinutos(int min, int max) => min == max ? '$min min' : '$min–$max min';

/// "hace 5 min", "hace 2 h", "12/03"
String haceCuanto(DateTime fecha) {
  final dif = DateTime.now().difference(fecha);
  if (dif.inMinutes < 1) return tx('ahora', 'now');
  if (dif.inMinutes < 60) return tx('hace ${dif.inMinutes} min', '${dif.inMinutes} min ago');
  if (dif.inHours < 24) return tx('hace ${dif.inHours} h', '${dif.inHours} h ago');
  return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
}

String fechaCorta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${textoHora(minutosDelDia(d))}';

const diasSemanaCortos = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

String nombreDiaSemana(int d) => switch (d) {
      1 => tx('lunes', 'Monday'),
      2 => tx('martes', 'Tuesday'),
      3 => tx('miércoles', 'Wednesday'),
      4 => tx('jueves', 'Thursday'),
      5 => tx('viernes', 'Friday'),
      6 => tx('sábado', 'Saturday'),
      _ => tx('domingo', 'Sunday'),
    };
