import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class EtiquetaHoraPico extends StatelessWidget {
  const EtiquetaHoraPico({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAcento),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 14, color: kAcento),
          SizedBox(width: 4),
          Text('Hora pico', style: TextStyle(fontSize: 12, color: kAcento)),
        ],
      ),
    );
  }
}
