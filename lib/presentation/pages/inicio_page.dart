import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/app_view_models.dart';
import '../widgets/buscador_destino.dart';
import '../widgets/etiqueta_hora_pico.dart';
import '../widgets/lista_rutas.dart';
import '../widgets/mapa_simulado.dart';
import 'perfil_page.dart';
import 'reportar_camion_page.dart';
import 'reportes_page.dart';

/// Dashboard del Alumno (mapa + rutas cercanas).
class InicioPage extends StatefulWidget {
  final AppViewModels vms;

  const InicioPage({super.key, required this.vms});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  @override
  void initState() {
    super.initState();
    widget.vms.inicio.cargarRutas();
  }

  void _abrir(Widget pagina) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Zona del mapa con buscador encima
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  const Positioned.fill(child: MapaSimulado()),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: BuscadorDestino(onChanged: vms.inicio.filtrar),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'ubicacion',
                      onPressed: () {},
                      backgroundColor: kSuperficie,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
            // Lista de rutas cercanas
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: kFondo,
                  border: Border(top: BorderSide(color: kBorde)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RUTAS CERCANAS',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: kTextoSecundario,
                            ),
                          ),
                          EtiquetaHoraPico(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: vms.inicio,
                        builder: (context, _) =>
                            ListaRutas(viewModel: vms.inicio),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Botón para reportar el paso del camión
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'reportar',
        onPressed: () => _abrir(ReportarCamionPage(viewModel: vms.reportes)),
        backgroundColor: kAcento,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Reportar camión'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        backgroundColor: kSuperficie,
        indicatorColor: kAcento.withOpacity(0.25),
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) _abrir(ReportesPage(viewModel: vms.reportes));
          if (i == 2) _abrir(PerfilPage(vms: vms));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Inicio',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Reportes'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
