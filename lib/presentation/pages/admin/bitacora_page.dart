import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Registro de cada cambio hecho por un administrador (últimos 200).
class BitacoraPage extends StatelessWidget {
  final AppViewModels vms;
  const BitacoraPage({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bitácora')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: vms.admin.bitacora(),
        builder: (context, snap) {
          if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!));
          if (!snap.hasData) return const Cargando();
          if (snap.data!.isEmpty) return const EstadoVacio(mensaje: 'Sin cambios registrados');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.length,
            separatorBuilder: (_, __) => const Divider(color: kBorde, height: 1),
            itemBuilder: (context, i) {
              final f = snap.data![i];
              final quien = (f['perfil'] as Map?)?['nombre'] ?? 'Sistema';
              final cuando = DateTime.parse(f['creado_en'] as String).toLocal();
              return ListTile(
                dense: true,
                leading: Icon(_icono(f['accion'] as String), color: kTextoSecundario),
                title: Text('${f['accion']} · ${f['entidad']} ${f['id_entidad'] ?? ''}'),
                subtitle: Text('$quien · ${fechaCorta(cuando)}'),
              );
            },
          );
        },
      ),
    );
  }

  IconData _icono(String accion) => switch (accion) {
        'insert' => Icons.add_circle_outline,
        'delete' => Icons.remove_circle_outline,
        'moderar' => Icons.gavel_outlined,
        _ => Icons.edit_outlined,
      };
}
