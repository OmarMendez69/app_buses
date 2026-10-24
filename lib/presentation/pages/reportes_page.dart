import 'package:flutter/material.dart';
 
import '../../core/theme/app_colors.dart';
import '../../domain/entities/reporte.dart';
import '../viewmodels/reportes_view_model.dart';
import '../widgets/estado_vacio.dart';
 
/// Lista de reportes del paso de camiones (el más reciente primero).
class ReportesPage extends StatelessWidget {
  final ReportesViewModel viewModel;
 
  const ReportesPage({super.key, required this.viewModel});
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes'), backgroundColor: kFondo),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final reportes = viewModel.reportes;
            if (reportes.isEmpty) {
              return const EstadoVacio(
                mensaje: 'No hay reportes todavía',
                icono: Icons.campaign_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reportes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _TarjetaReporte(reporte: reportes[i]),
            );
          },
        ),
      ),
    );
  }
}
 
class _TarjetaReporte extends StatelessWidget {
  final Reporte reporte;
 
  const _TarjetaReporte({required this.reporte});
 
  /// Color e ícono según el tipo de reporte.
  (Color, IconData) get _estilo {
    switch (reporte.tipo) {
      case 'Ya pasó':
        return (Colors.greenAccent, Icons.check_circle_outline);
      case 'Viene lleno':
        return (Colors.orangeAccent, Icons.groups_outlined);
      default:
        return (kAcento, Icons.schedule);
    }
  }
 
  String get _hace {
    final min = DateTime.now().difference(reporte.hora).inMinutes;
    if (min < 1) return 'Hace un momento';
    if (min < 60) return 'Hace $min min';
    final h = reporte.hora.hour.toString().padLeft(2, '0');
    final m = reporte.hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
 
  @override
  Widget build(BuildContext context) {
    final (color, icono) = _estilo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSuperficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reporte.ruta,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _hace,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kTextoSecundario,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reporte.parada,
                  style: const TextStyle(color: kTextoSecundario),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reporte.tipo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (reporte.comentario.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(reporte.comentario),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}