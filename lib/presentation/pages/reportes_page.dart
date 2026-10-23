import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/reportes_view_model.dart';

/// TODO (compañero): reemplazar este placeholder por la lista de reportes.
/// Requisitos: ver PARA_COMPANERO/PROMPT.md
class ReportesPage extends StatelessWidget {
  final ReportesViewModel viewModel;

  const ReportesPage({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes'), backgroundColor: kFondo),
      body: const Center(
        child: Text(
          'Pendiente: lista de reportes (compañero)',
          style: TextStyle(color: kTextoSecundario),
        ),
      ),
    );
  }
}
