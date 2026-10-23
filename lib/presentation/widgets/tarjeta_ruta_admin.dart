import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/ruta.dart';

/// Colores disponibles para una ruta.
const List<String> coloresRuta = ['Rojo', 'Azul', 'Verde', 'Naranja'];

Color colorDeRuta(String nombre) {
  switch (nombre) {
    case 'Azul':
      return Colors.blueAccent;
    case 'Verde':
      return Colors.green;
    case 'Naranja':
      return Colors.orange;
    default:
      return kAcento;
  }
}

/// Tarjeta de una ruta en el panel del administrador.
class TarjetaRutaAdmin extends StatelessWidget {
  final Ruta ruta;
  final VoidCallback onEditar;

  const TarjetaRutaAdmin({
    super.key,
    required this.ruta,
    required this.onEditar,
  });

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
            width: 14,
            height: 48,
            decoration: BoxDecoration(
              color: colorDeRuta(ruta.color),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ruta.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cada ${ruta.frecuenciaAproxMin} min · '
                  '${ruta.activa ? 'Activa' : 'Inactiva'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: ruta.activa ? Colors.greenAccent : kTextoSecundario,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar ruta',
            icon: const Icon(Icons.edit_outlined, color: kAcento),
            onPressed: onEditar,
          ),
        ],
      ),
    );
  }
}
