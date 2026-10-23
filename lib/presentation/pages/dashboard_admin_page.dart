import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/ruta.dart';
import '../navigation/navegacion.dart';
import '../viewmodels/app_view_models.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/tarjeta_metrica.dart';
import '../widgets/tarjeta_ruta_admin.dart';
import '../widgets/titulo_seccion.dart';
import 'formulario_ruta_page.dart';
import 'reportes_page.dart';

/// Dashboard del Administrador: gestiona rutas (agregar / editar).
class DashboardAdminPage extends StatelessWidget {
  final AppViewModels vms;

  const DashboardAdminPage({super.key, required this.vms});

  void _abrirFormulario(BuildContext context, [Ruta? ruta]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormularioRutaPage(
          viewModel: vms.rutasAdmin,
          ruta: ruta,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        backgroundColor: kSuperficie,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => cerrarSesion(context, vms),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([vms.sesion, vms.rutasAdmin, vms.reportes]),
        builder: (context, _) {
          final rutas = vms.rutasAdmin.rutas;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TarjetaMetrica(
                        icono: Icons.group_outlined,
                        valor: '${vms.sesion.totalUsuarios}',
                        etiqueta: 'Usuarios',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TarjetaMetrica(
                        icono: Icons.alt_route,
                        valor: '${vms.rutasAdmin.totalActivas}',
                        etiqueta: 'Rutas activas',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TarjetaMetrica(
                        icono: Icons.campaign_outlined,
                        valor: '${vms.reportes.reportes.length}',
                        etiqueta: 'Reportes',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportesPage(viewModel: vms.reportes),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Ver reportes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAcento,
                    side: const BorderSide(color: kAcento),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: TituloSeccion('RUTAS REGISTRADAS'),
              ),
              Expanded(
                child: rutas.isEmpty
                    ? const EstadoVacio(mensaje: 'No hay rutas registradas')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: rutas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => TarjetaRutaAdmin(
                          ruta: rutas[i],
                          onEditar: () => _abrirFormulario(context, rutas[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        backgroundColor: kAcento,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva ruta'),
      ),
    );
  }
}
