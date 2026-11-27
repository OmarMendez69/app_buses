import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Días especiales: en esas fechas la app usa otro horario automáticamente
/// (ej. 16 de septiembre → horario de domingo o festivo).
class CalendarioPage extends StatelessWidget {
  final AppViewModels vms;
  const CalendarioPage({super.key, required this.vms});

  Future<void> _nuevo(BuildContext context) async {
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (fecha == null || !context.mounted) return;
    final nombre = TextEditingController();
    TipoDia td = TipoDia.domingoFestivo;
    int? aviso;
    final avisos = vms.catalogo.cat.avisos;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Día especial: ${claveFecha(fecha)}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nombre, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre (ej. Fiestas patrias)')),
            DropdownButtonFormField<TipoDia>(
              initialValue: td,
              decoration: const InputDecoration(labelText: 'Horario que aplica'),
              items: [for (final t in TipoDia.values) DropdownMenuItem(value: t, child: Text(t.etiqueta))],
              onChanged: (v) => set(() => td = v ?? td),
            ),
            DropdownButtonFormField<int?>(
              initialValue: aviso,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Aviso ligado (opcional)'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Ninguno')),
                for (final a in avisos) DropdownMenuItem<int?>(value: a.id, child: Text(a.titulo, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => set(() => aviso = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    try {
      await vms.admin.guardarDiaEspecial(fecha, nombre.text.trim(), td, aviso);
      await vms.catalogo.refrescar();
    } catch (e) {
      if (context.mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Días especiales')),
      floatingActionButton: FloatingActionButton(backgroundColor: kAcento, onPressed: () => _nuevo(context), child: const Icon(Icons.add)),
      body: ListenableBuilder(
        listenable: vms.catalogo,
        builder: (context, _) {
          final lista = [...vms.catalogo.cat.diasEspeciales]..sort((a, b) => a.fecha.compareTo(b.fecha));
          if (lista.isEmpty) return const EstadoVacio(mensaje: 'Agrega festivos y fiestas locales.');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final d in lista)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event, color: kAcento),
                    title: Text(d.nombre),
                    subtitle: Text('${claveFecha(d.fecha)} · horario de ${d.tipoDia.etiqueta.toLowerCase()}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        try {
                          await vms.admin.borrarDiaEspecial(d.fecha);
                          await vms.catalogo.refrescar();
                        } catch (e) {
                          if (context.mounted) avisar(context, mensajeError(e));
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
