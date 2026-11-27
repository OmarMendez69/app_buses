import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/idioma.dart';
import '../core/tiempo.dart';
import '../domain/catalogo.dart';

/// Widget de Android: tus rutas seguidas con su estado, sin abrir la app.
/// Se actualiza cada vez que la app se abre o cambian tus rutas.
class WidgetInicio {
  static Future<void> actualizar(Catalogo cat, Set<int> rutas) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final ahora = DateTime.now();
      final lineas = <String>[];
      for (final id in rutas) {
        final r = cat.rutaPorId[id];
        if (r == null || !r.activa) continue;
        final e = cat.estadoRuta(id, ahora);
        final estado = e.enServicio
            ? tx('cada ${rangoMinutos(e.frecuenciaMin!, e.frecuenciaMax!)}', 'every ${rangoMinutos(e.frecuenciaMin!, e.frecuenciaMax!)}')
            : e.proximoInicio != null
                ? tx('inicia ${textoHora(e.proximoInicio!)}', 'starts ${textoHora(e.proximoInicio!)}')
                : e.inicioManana != null
                    ? tx('mañana ${textoHora(e.inicioManana!)}', 'tomorrow ${textoHora(e.inicioManana!)}')
                    : tx('sin servicio', 'no service');
        lineas.add('${r.nombre} · $estado');
      }
      final texto = lineas.isEmpty ? tx('Sigue una ruta para verla aquí', 'Follow a route to see it here') : lineas.join('\n');
      await HomeWidget.saveWidgetData<String>('rutas_texto', texto);
      await HomeWidget.saveWidgetData<String>('actualizado', tx('Actualizado ${textoHora(minutosDelDia(ahora))}', 'Updated ${textoHora(minutosDelDia(ahora))}'));
      await HomeWidget.updateWidget(androidName: 'RutasWidgetProvider');
    } catch (e) {
      debugPrint('Widget: $e');
    }
  }
}
