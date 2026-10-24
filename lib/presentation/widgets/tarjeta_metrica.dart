import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Tarjeta con un número grande y su etiqueta (para los dashboards).
class TarjetaMetrica extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const TarjetaMetrica({
    super.key,
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSuperficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: kAcento),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 12, color: kTextoSecundario),
          ),
        ],
      ),
    );
  }
}
