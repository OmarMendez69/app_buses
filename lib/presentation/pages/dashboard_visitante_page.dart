import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../navigation/navegacion.dart';
import '../viewmodels/app_view_models.dart';
import '../widgets/etiqueta_hora_pico.dart';
import '../widgets/lista_rutas.dart';
import '../widgets/titulo_seccion.dart';
import 'reportar_camion_page.dart';
import 'reportes_page.dart';

/// Dashboard del Visitante: consulta rutas y puede reportar, sin mapa ni perfil completo.
class DashboardVisitantePage extends StatefulWidget {
  final AppViewModels vms;

  const DashboardVisitantePage({super.key, required this.vms});

  @override
  State<DashboardVisitantePage> createState() => _DashboardVisitantePageState();
}

class _DashboardVisitantePageState extends State<DashboardVisitantePage> {
  @override
  void initState() {
    super.initState();
    widget.vms.inicio.cargarRutas();
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido, visitante'),
        backgroundColor: kSuperficie,
        actions: [
          IconButton(
            tooltip: 'Ver reportes',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportesPage(viewModel: vms.reportes),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => cerrarSesion(context, vms),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Hola, ${vms.sesion.usuarioActual?.nombre ?? ''}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TituloSeccion('RUTAS DISPONIBLES'),
                EtiquetaHoraPico(),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: vms.inicio,
              builder: (context, _) => ListaRutas(viewModel: vms.inicio),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportarCamionPage(viewModel: vms.reportes),
          ),
        ),
        backgroundColor: kAcento,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Reportar camión'),
      ),
    );
  }
}
