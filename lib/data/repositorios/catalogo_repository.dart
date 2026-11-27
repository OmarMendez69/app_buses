import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/catalogo.dart';
import '../../domain/entities/transporte.dart';
import '../cache_local.dart';

/// Descarga el catálogo del transporte y lo guarda en el teléfono.
class CatalogoRepository {
  final SupabaseClient _db;
  final CacheLocal _cache;

  CatalogoRepository(this._db, this._cache);

  Future<Catalogo?> desdeCache() async {
    final datos = await _cache.leerCatalogo();
    if (datos == null) return null;
    try {
      return _armar(datos);
    } catch (_) {
      return null;
    }
  }

  Future<Catalogo> descargar() async {
    final hace7dias = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
    final ahora = DateTime.now().toUtc().toIso8601String();

    final resultados = await Future.wait([
      _db.from('ruta').select(),
      _db.from('recorrido').select(),
      _db.from('recorrido_parada').select(),
      _db.from('parada').select(),
      _db.from('franja_servicio').select(),
      _db.from('lugar').select(),
      _db.from('horario_lugar').select(),
      // Avisos vigentes o creados en los últimos 7 días
      _db.from('aviso_servicio').select().or('vigente_hasta.is.null,vigente_hasta.gt."$ahora",creado_en.gt."$hace7dias"'),
      _db.from('aviso_parada').select(),
      _db.from('dia_especial').select(),
    ]);

    final datos = <String, dynamic>{
      'ruta': resultados[0],
      'recorrido': resultados[1],
      'recorrido_parada': resultados[2],
      'parada': resultados[3],
      'franja_servicio': resultados[4],
      'lugar': resultados[5],
      'horario_lugar': resultados[6],
      'aviso_servicio': resultados[7],
      'aviso_parada': resultados[8],
      'dia_especial': resultados[9],
      'actualizado': DateTime.now().toIso8601String(),
    };
    await _cache.guardarCatalogo(datos);
    return _armar(datos);
  }

  Catalogo _armar(Map<String, dynamic> d) {
    List<Map<String, dynamic>> l(String k) => ((d[k] as List?) ?? const []).cast<Map<String, dynamic>>();

    final paradasPorRecorrido = <int, List<ParadaEnRecorrido>>{};
    for (final j in l('recorrido_parada')) {
      paradasPorRecorrido.putIfAbsent(j['id_recorrido'] as int, () => []).add(ParadaEnRecorrido.fromJson(j));
    }
    final paradasPorAviso = <int, List<int>>{};
    for (final j in l('aviso_parada')) {
      paradasPorAviso.putIfAbsent(j['id_aviso'] as int, () => []).add(j['id_parada'] as int);
    }

    return Catalogo(
      rutas: l('ruta').map(Ruta.fromJson).toList(),
      recorridos: l('recorrido')
          .map((j) => Recorrido.fromJson(j, paradasPorRecorrido[j['id_recorrido'] as int] ?? []))
          .toList(),
      paradas: l('parada').map(Parada.fromJson).toList(),
      franjas: l('franja_servicio').map(Franja.fromJson).toList(),
      lugares: l('lugar').map(Lugar.fromJson).toList(),
      horarios: l('horario_lugar').map(HorarioLugar.fromJson).toList(),
      avisos: l('aviso_servicio')
          .map((j) => Aviso.fromJson(j, paradasPorAviso[j['id_aviso'] as int] ?? const []))
          .toList(),
      diasEspeciales: l('dia_especial').map(DiaEspecial.fromJson).toList(),
      actualizado: DateTime.tryParse(d['actualizado']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Escucha cambios en vivo (avisos, rutas, horarios) para refrescar la app abierta.
  RealtimeChannel escucharCambios(void Function(String tabla) alCambiar) {
    final canal = _db.channel('catalogo');
    for (final tabla in ['aviso_servicio', 'ruta', 'franja_servicio']) {
      canal.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabla,
        callback: (_) => alCambiar(tabla),
      );
    }
    return canal.subscribe();
  }
}
