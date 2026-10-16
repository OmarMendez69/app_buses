import 'rutas_data_source.dart';

class RutasMockDataSource implements RutasDataSource {
  @override
  Future<List<Map<String, dynamic>>> obtenerRutas() async {
    return const [
      {
        'nombre': 'Ruta 1',
        'recorrido': 'Centro – UTNG',
        'parada': 'Parada Plaza Principal',
        'distancia': '150 m',
        'proximo': '5 min',
      },
      {
        'nombre': 'Ruta 2',
        'recorrido': 'Col. Cruz Blanca – Centro',
        'parada': 'Parada Av. Hidalgo',
        'distancia': '320 m',
        'proximo': '12 min',
      },
      {
        'nombre': 'Ruta 3',
        'recorrido': 'Terminal – UTNG',
        'parada': 'Parada Central Camionera',
        'distancia': '600 m',
        'proximo': '18 min',
      },
    ];
  }
}
