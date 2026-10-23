import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../navigation/navegacion.dart';
import '../viewmodels/app_view_models.dart';

class PerfilPage extends StatelessWidget {
  final AppViewModels vms;

  const PerfilPage({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    final usuario = vms.sesion.usuarioActual;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil'), backgroundColor: kFondo),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const CircleAvatar(
              radius: 44,
              backgroundColor: kSuperficie,
              child: Icon(Icons.person, size: 48, color: kAcento),
            ),
            const SizedBox(height: 16),
            Text(
              usuario?.nombre ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              usuario?.correo ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextoSecundario),
            ),
            const SizedBox(height: 12),
            Center(
              child: Chip(
                label: Text(usuario?.rol.etiqueta ?? ''),
                side: const BorderSide(color: kAcento),
                backgroundColor: kFondo,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reputación: ${usuario?.reputacion ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextoSecundario),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => cerrarSesion(context, vms),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kAcento,
                side: const BorderSide(color: kAcento),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
