import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/inicio_view_model.dart';
import 'tarjeta_ruta.dart';

class ListaRutas extends StatelessWidget {
  final InicioViewModel viewModel;

  const ListaRutas({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    switch (viewModel.estado) {
      case EstadoCarga.cargando:
        return const Center(child: CircularProgressIndicator(color: kAcento));
      case EstadoCarga.error:
        return const Center(
          child: Text(
            'No se pudieron cargar las rutas',
            style: TextStyle(color: kTextoSecundario),
          ),
        );
      case EstadoCarga.exito:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          itemCount: viewModel.rutas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => TarjetaRuta(ruta: viewModel.rutas[i]),
        );
    }
  }
}
