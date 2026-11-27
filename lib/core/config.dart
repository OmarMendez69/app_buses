/// Configuración que se pasa al compilar:
///   flutter run --dart-define-from-file=config.json
/// config.json (no se sube a GitHub):
///   { "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "eyJ..." }
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get completa => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Centro de Dolores Hidalgo (Jardín Principal), para centrar el mapa sin GPS.
  static const centroLat = 21.1564;
  static const centroLng = -100.9343;

  /// Radios del sistema (metros)
  static const radioCercania = 500.0;
  static const radioAbordaje = 600.0;
  static const radioTransbordo = 150.0;
  static const radioQuePasaAqui = 100.0;
  static const radioLugarDemanda = 400.0;
  static const avisoBajadaMetros = 300.0;

  /// Velocidad media a pie (m/min) para la caminata en línea recta
  static const velocidadPie = 75.0;

  /// Factor de rodeo de calles sobre la línea recta
  static const factorCalles = 1.3;

  /// Etiqueta para el servidor de teselas de OpenStreetMap
  static const userAgent = 'mx.dolores.camiones';
}
