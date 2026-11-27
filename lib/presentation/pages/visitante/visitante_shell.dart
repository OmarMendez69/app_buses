import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../domain/entities/transporte.dart';
import '../../../domain/entities/viaje.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import '../../widgets/selector_punto.dart';
import '../acceso/registro_page.dart';
import '../comun/avisos_page.dart';
import '../comun/hora_pico_page.dart';
import '../comun/parada_detalle_page.dart';
import '../comun/planificador_page.dart';
import '../comun/que_pasa_aqui_page.dart';
import '../comun/ruta_detalle_page.dart';
import '../comun/rutas_page.dart';
import '../comun/tablon_page.dart';
import '../usuario/perfil_page.dart';

/// Dashboard del Visitante (sin cuenta): Rutas · Planificar · Tablón.
class VisitanteShell extends StatefulWidget {
  final AppViewModels vms;
  const VisitanteShell({super.key, required this.vms});

  @override
  State<VisitanteShell> createState() => _VisitanteShellState();
}

class _VisitanteShellState extends State<VisitanteShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final paginas = [
      RutasDisponiblesPage(vms: widget.vms),
      PlanificadorPage(vms: widget.vms, comoPestana: true),
      TablonPage(vms: widget.vms),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        indicatorColor: kAcento.withValues(alpha: 0.3),
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.directions_bus_outlined), label: tx('Rutas', 'Routes')),
          NavigationDestination(icon: const Icon(Icons.alt_route), label: tx('Planificar', 'Plan')),
          NavigationDestination(icon: const Icon(Icons.forum_outlined), label: tx('Tablón', 'Board')),
        ],
      ),
    );
  }
}

/// "Rutas disponibles": la pantalla principal del visitante.
class RutasDisponiblesPage extends StatelessWidget {
  final AppViewModels vms;
  const RutasDisponiblesPage({super.key, required this.vms});

  Future<void> _aDonde(BuildContext context) async {
    final destino = await elegirPunto(context, vms, titulo: tx('¿A dónde vas?', 'Where to?'));
    if (destino != null && context.mounted) abrir(context, PlanificadorPage(vms: vms, destinoInicial: destino));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Bienvenido, visitante', 'Welcome, visitor')),
        actions: [
          _Campana(vms: vms),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'cuenta':
                  abrir(context, RegistroPage(vms: vms));
                case 'entrar':
                  cerrarSesion(context, vms);
                case 'ajustes':
                  abrir(context, PerfilPage(vms: vms));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'cuenta', child: Text(tx('Crear cuenta', 'Create account'))),
              PopupMenuItem(value: 'entrar', child: Text(tx('Iniciar sesión', 'Sign in'))),
              PopupMenuItem(value: 'ajustes', child: Text(tx('Ajustes', 'Settings'))),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([vms.catalogo, vms.favoritos]),
        builder: (context, _) {
          final cat = vms.catalogo.cat;
          final ahora = DateTime.now();
          final generales = cat.avisosVigentes(ahora).where((a) => a.idRuta == null).toList();
          final rapidos = [
            ...cat.lugaresActivos.where((l) => l.categoria == CategoriaLugar.turismo),
            ...cat.lugaresActivos.where((l) => l.categoria == CategoriaLugar.transporte),
            ...cat.lugaresActivos.where((l) => l.categoria == CategoriaLugar.educacion || l.categoria == CategoriaLugar.salud),
          ].take(8).toList();

          return RefreshIndicator(
            onRefresh: vms.catalogo.refrescar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (vms.catalogo.desdeCache && vms.catalogo.error != null) BannerSinConexion(actualizado: cat.actualizado),
                BuscadorADonde(alTocar: () => _aDonde(context)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 230,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(children: [
                      MapaBase(
                        centro: vms.catalogo.ubicacion,
                        zoom: 14,
                        capas: [
                          capaRecorridos(cat.geosActivos, grosor: 4),
                          MarkerLayer(markers: [
                            for (final p in cat.paradasActivas)
                              marcadorParada(p, tam: 12, alTocar: () => abrir(context, ParadaDetallePage(vms: vms, idParada: p.id))),
                            if (vms.catalogo.ubicacion != null) marcadorYo(vms.catalogo.ubicacion!),
                          ]),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FloatingActionButton.small(
                          heroTag: 'ubicar_visitante',
                          backgroundColor: kSuperficie,
                          tooltip: tx('Mi ubicación', 'My location'),
                          onPressed: () => vms.catalogo.actualizarUbicacion(),
                          child: const Icon(Icons.my_location, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
                if (rapidos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in rapidos)
                        ActionChip(
                          avatar: const Icon(Icons.place_outlined, size: 16),
                          label: Text(l.nombre),
                          onPressed: () => abrir(context, PlanificadorPage(vms: vms, destinoInicial: PuntoNombrado(l.nombre, l.punto))),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => abrir(context, QuePasaAquiPage(vms: vms)),
                  icon: const Icon(Icons.near_me_outlined),
                  label: Text(tx('¿Qué rutas pasan por aquí?', 'Which routes pass here?')),
                ),
                for (final a in generales) TarjetaAviso(aviso: a, alTocar: () => abrir(context, AvisosPage(vms: vms))),
                TituloSeccion(
                  tx('Rutas disponibles', 'Available routes'),
                  accion: OutlinedButton.icon(
                    onPressed: () => abrir(context, HoraPicoPage(vms: vms)),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(tx('Hora pico', 'Peak hours')),
                    style: OutlinedButton.styleFrom(foregroundColor: kAcento, side: const BorderSide(color: kAcento)),
                  ),
                ),
                if (cat.rutasActivas.isEmpty)
                  EstadoVacio(
                    mensaje: vms.catalogo.cargando ? tx('Cargando rutas…', 'Loading routes…') : tx('Aún no hay rutas publicadas', 'No routes published yet'),
                    icono: Icons.directions_bus_outlined,
                  ),
                for (final r in cat.rutasActivas)
                  TarjetaRuta(
                    ruta: r,
                    estado: cat.estadoRuta(r.id, ahora),
                    detalle: '\$${r.tarifa.toStringAsFixed(2)}${r.letrero == null ? '' : ' · ${r.letrero}'}',
                    accion: IconButton(
                      icon: Icon(vms.favoritos.sigue(r.id) ? Icons.star : Icons.star_border, color: kAmbar),
                      onPressed: () => vms.favoritos.alternar(r.id),
                    ),
                    alTocar: () => abrir(context, RutaDetallePage(vms: vms, idRuta: r.id)),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => abrir(context, RutasPage(vms: vms)),
                  child: Text(tx('Ver paradas', 'See stops')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Campo "¿A dónde vas?" que abre el buscador.
class BuscadorADonde extends StatelessWidget {
  final VoidCallback alTocar;
  const BuscadorADonde({super.key, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSuperficie,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            const Icon(Icons.search, color: kAcento),
            const SizedBox(width: 12),
            Text(tx('¿A dónde vas?', 'Where to?'), style: const TextStyle(color: kTextoSecundario, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

class _Campana extends StatelessWidget {
  final AppViewModels vms;
  const _Campana({required this.vms});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vms.catalogo,
      builder: (context, _) {
        final n = vms.catalogo.cat.avisosVigentes(DateTime.now()).length;
        return IconButton(
          tooltip: tx('Avisos', 'Notices'),
          onPressed: () => abrir(context, AvisosPage(vms: vms)),
          icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.notifications_outlined)),
        );
      },
    );
  }
}

/// Exportada para el dashboard del usuario.
class Campana extends StatelessWidget {
  final AppViewModels vms;
  const Campana({super.key, required this.vms});
  @override
  Widget build(BuildContext context) => _Campana(vms: vms);
}
