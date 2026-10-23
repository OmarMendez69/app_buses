import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class TituloSeccion extends StatelessWidget {
  final String texto;

  const TituloSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
        color: kTextoSecundario,
      ),
    );
  }
}
