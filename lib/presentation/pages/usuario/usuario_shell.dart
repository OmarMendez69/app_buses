import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../viewmodels/app_view_models.dart';
import '../comun/planificador_page.dart';
import '../comun/rutas_page.dart';
import '../comun/tablon_page.dart';
import 'inicio_mapa_page.dart';
import 'perfil_page.dart';

/// Dashboard del Usuario: Inicio · Rutas · Planificar · Tablón · Perfil.
class UsuarioShell extends StatefulWidget {
  final AppViewModels vms;
  const UsuarioShell({super.key, required this.vms});

  @override
  State<UsuarioShell> createState() => _UsuarioShellState();
}

class _UsuarioShellState extends State<UsuarioShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    final paginas = [
      InicioMapaPage(vms: vms),
      RutasPage(vms: vms),
      PlanificadorPage(vms: vms, comoPestana: true),
      TablonPage(vms: vms),
      PerfilPage(vms: vms, comoPestana: true),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        indicatorColor: kAcento.withValues(alpha: 0.3),
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map_outlined), label: tx('Inicio', 'Home')),
          NavigationDestination(icon: const Icon(Icons.directions_bus_outlined), label: tx('Rutas', 'Routes')),
          NavigationDestination(icon: const Icon(Icons.alt_route), label: tx('Planificar', 'Plan')),
          NavigationDestination(icon: const Icon(Icons.forum_outlined), label: tx('Tablón', 'Board')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: tx('Perfil', 'Profile')),
        ],
      ),
    );
  }
}
