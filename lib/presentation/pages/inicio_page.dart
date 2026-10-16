import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/inicio_view_model.dart';
import '../widgets/buscador_destino.dart';
import '../widgets/etiqueta_hora_pico.dart';
import '../widgets/lista_rutas.dart';
import '../widgets/mapa_simulado.dart';

class InicioPage extends StatefulWidget {
  final InicioViewModel viewModel;

  const InicioPage({super.key, required this.viewModel});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int _indiceNav = 0;

  @override
  void initState() {
    super.initState();
    widget.viewModel.cargarRutas();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: BuscadorDestino(),
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
                        listenable: widget.viewModel,
                        builder: (context, _) =>
                            ListaRutas(viewModel: widget.viewModel),
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
        onPressed: () {},
        backgroundColor: kAcento,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Reportar camión'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        backgroundColor: kSuperficie,
        indicatorColor: kAcento.withOpacity(0.25),
        selectedIndex: _indiceNav,
        onDestinationSelected: (i) => setState(() => _indiceNav = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Inicio',
          ),
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'Rutas'),
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
