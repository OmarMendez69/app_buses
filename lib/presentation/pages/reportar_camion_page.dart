import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/reportes_view_model.dart';

/// TODO (compañero): reemplazar este placeholder por el formulario.
/// Requisitos: ver PARA_COMPANERO/PROMPT.md
class ReportarCamionPage extends StatelessWidget {
  final ReportesViewModel viewModel;

  const ReportarCamionPage({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar camión'),
        backgroundColor: kFondo,
      ),
      body: const Center(
        child: Text(
          'Pendiente: formulario de reporte (compañero)',
          style: TextStyle(color: kTextoSecundario),
        ),
      ),
    );
  }
}
