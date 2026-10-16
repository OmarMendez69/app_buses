import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/ruta_cercana.dart';

class TarjetaRuta extends StatelessWidget {
  final RutaCercana ruta;

  const TarjetaRuta({super.key, required this.ruta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSuperficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorde),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kAcento,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_bus, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ruta.nombre} · ${ruta.recorrido}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ruta.parada} · ${ruta.distancia}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ruta.proximo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kAcento,
                ),
              ),
              const Text(
                'próximo',
                style: TextStyle(fontSize: 11, color: kTextoSecundario),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
