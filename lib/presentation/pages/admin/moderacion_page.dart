import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/admin_repository.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Cola de contenido denunciado. Con 3 denuncias se oculta solo mientras se revisa.
/// Queda registrado quién decidió y cuándo.
class ModeracionPage extends StatefulWidget {
  final AppViewModels vms;
  const ModeracionPage({super.key, required this.vms});

  @override
  State<ModeracionPage> createState() => _ModeracionPageState();
}

class _ModeracionPageState extends State<ModeracionPage> {
  late Future<List<DenunciaAdmin>> _lista;

  @override
  void initState() {
    super.initState();
    _lista = widget.vms.admin.denunciasPendientes();
  }

  Future<void> _resolver(DenunciaAdmin d, bool procede) async {
    try {
      await widget.vms.admin.resolverDenuncia(d.id, procede);
      setState(() => _lista = widget.vms.admin.denunciasPendientes());
      if (mounted) avisar(context, procede ? 'Contenido ocultado' : 'Contenido mantenido');
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderación del tablón')),
      body: FutureBuilder<List<DenunciaAdmin>>(
        future: _lista,
        builder: (context, snap) {
          if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!));
          if (!snap.hasData) return const Cargando();
          if (snap.data!.isEmpty) return const EstadoVacio(mensaje: 'No hay denuncias pendientes', icono: Icons.verified_outlined);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final d in snap.data!)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.idPublicacion != null ? 'Publicación' : 'Comentario', style: const TextStyle(color: kAmbar)),
                      const SizedBox(height: 6),
                      Text(d.texto, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Autor: ${d.autor} · Motivo: ${d.motivo} · ${fechaCorta(d.creadoEn)}', style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                      FutureBuilder<int>(
                        future: widget.vms.admin.contarDenuncias(d.idPublicacion, d.idComentario),
                        builder: (context, s) => Text('Denuncias pendientes: ${s.data ?? '…'}', style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(onPressed: () => _resolver(d, false), child: const Text('Mantener visible')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: kAcento),
                            onPressed: () => _resolver(d, true),
                            child: const Text('Ocultar'),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
