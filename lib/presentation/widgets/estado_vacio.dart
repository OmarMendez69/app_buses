import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Mensaje centrado para listas sin elementos ("No hay elementos").
class EstadoVacio extends StatelessWidget {
  final String mensaje;
  final IconData icono;

  const EstadoVacio({
    super.key,
    required this.mensaje,
    this.icono = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: kTextoSecundario),
          const SizedBox(height: 8),
          Text(mensaje, style: const TextStyle(color: kTextoSecundario)),
        ],
      ),
    );
  }
}
