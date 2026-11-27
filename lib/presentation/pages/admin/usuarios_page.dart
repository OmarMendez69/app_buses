import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/admin_repository.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

class UsuariosPage extends StatefulWidget {
  final AppViewModels vms;
  const UsuariosPage({super.key, required this.vms});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  late Future<List<UsuarioAdmin>> _lista;
  String _filtro = 'todos';
  String _q = '';

  @override
  void initState() {
    super.initState();
    _lista = widget.vms.admin.usuarios();
  }

  Future<void> _cambiar(UsuarioAdmin u, {bool? admin, bool? suspendido}) async {
    try {
      await widget.vms.admin.actualizarUsuario(u.id, admin ?? u.esAdmin, suspendido ?? u.suspendido);
      setState(() => _lista = widget.vms.admin.usuarios());
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final yo = widget.vms.sesion.perfil?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: FutureBuilder<List<UsuarioAdmin>>(
        future: _lista,
        builder: (context, snap) {
          if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!));
          if (!snap.hasData) return const Cargando();
          var lista = snap.data!;
          if (_filtro == 'admin') lista = lista.where((u) => u.esAdmin).toList();
          if (_filtro == 'suspendidos') lista = lista.where((u) => u.suspendido).toList();
          if (_q.isNotEmpty) {
            lista = lista.where((u) => quitarAcentos('${u.nombre} ${u.correo}').contains(quitarAcentos(_q))).toList();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(hintText: 'Buscar por nombre o correo', prefixIcon: Icon(Icons.search), filled: true, fillColor: kSuperficie),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'todos', label: Text('Todos')),
                  ButtonSegment(value: 'admin', label: Text('Admins')),
                  ButtonSegment(value: 'suspendidos', label: Text('Suspendidos')),
                ],
                selected: {_filtro},
                onSelectionChanged: (s) => setState(() => _filtro = s.first),
              ),
              const SizedBox(height: 8),
              for (final u in lista)
                Card(
                  child: ListTile(
                    leading: Icon(u.esAdmin ? Icons.admin_panel_settings : Icons.person_outline, color: u.suspendido ? Colors.redAccent : kAcento),
                    title: Text(u.nombre),
                    subtitle: Text('${u.correo}\n${u.publicaciones} publicaciones · desde ${fechaCorta(u.creadoEn).split(' ').first}'
                        '${u.suspendido ? ' · SUSPENDIDO' : ''}'),
                    isThreeLine: true,
                    trailing: u.id == yo
                        ? const Text('Tú', style: TextStyle(color: kTextoSecundario))
                        : PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'admin':
                                  _cambiar(u, admin: !u.esAdmin);
                                case 'suspender':
                                  _cambiar(u, suspendido: !u.suspendido);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'admin', child: Text(u.esAdmin ? 'Quitar rol de administrador' : 'Hacer administrador')),
                              PopupMenuItem(value: 'suspender', child: Text(u.suspendido ? 'Reactivar cuenta' : 'Suspender cuenta')),
                            ],
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
