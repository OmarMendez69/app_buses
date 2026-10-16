import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BuscadorDestino extends StatelessWidget {
  const BuscadorDestino({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: kSuperficie.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorde),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: '¿A dónde vas?',
          hintStyle: TextStyle(color: kTextoSecundario),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: kAcento),
          suffixIcon: Icon(Icons.mic_none, color: kTextoSecundario),
        ),
      ),
    );
  }
}
