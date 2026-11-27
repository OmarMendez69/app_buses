import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import 'avisos_admin_page.dart';
import 'bitacora_page.dart';
import 'calendario_page.dart';
import 'lugares_admin_page.dart';
import 'moderacion_page.dart';
import 'paradas_admin_page.dart';
import 'ruta_form_page.dart';
import 'usuarios_page.dart';

/// Dashboard del Administrador (dentro de la misma app; también se publica en web).
class AdminShell extends StatefulWidget {
  final AppViewModels vms;
  const AdminShell({super.key, required this.vms});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late Future<Map<String, dynamic>> _metricas;

  @override
  void initState() {
    super.initState();
    _metricas = widget.vms.admin.metricas();
  }

  Future<void> _refrescar() async {
    setState(() => _metricas = widget.vms.admin.metricas());
    await widget.vms.catalogo.refrescar();
  }

  Future<void> _ir(Widget pagina) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
    _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _refrescar),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: () => cerrarSesion(context, vms)),
        ],
      ),
      drawer: _menu(context),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAcento,
        onPressed: () => _ir(RutaFormPage(vms: vms)),
        icon: const Icon(Icons.add),
        label: const Text('Nueva ruta'),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _metricas,
              builder: (context, snap) {
                if (snap.hasError) return Text(mensajeError(snap.error!), style: const TextStyle(color: Colors.redAccent));
                final m = snap.data ?? const {};
                String v(String k) => snap.hasData ? '${m[k] ?? 0}' : '…';
                final sinRevisar = (m['rutas_sin_revisar'] as int?) ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        TarjetaMetrica(icono: Icons.people_outline, valor: v('usuarios'), etiqueta: 'Usuarios', alTocar: () => _ir(UsuariosPage(vms: vms))),
                        TarjetaMetrica(icono: Icons.alt_route, valor: v('rutas_activas'), etiqueta: 'Rutas activas'),
                        TarjetaMetrica(icono: Icons.campaign_outlined, valor: v('avisos_vigentes'), etiqueta: 'Avisos vigentes', alTocar: () => _ir(AvisosAdminPage(vms: vms))),
                        TarjetaMetrica(icono: Icons.flag_outlined, valor: v('denuncias_pendientes'), etiqueta: 'Denuncias pendientes', alTocar: () => _ir(ModeracionPage(vms: vms))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Publicaciones en el tablón (7 días): ${v('publicaciones_7d')}', style: const TextStyle(color: kTextoSecundario)),
                    if (sinRevisar > 0)
                      Card(
                        color: kAmbar.withValues(alpha: 0.12),
                        child: ListTile(
                          leading: const Icon(Icons.history, color: kAmbar),
                          title: Text('$sinRevisar ruta(s) llevan más de 90 días sin revisarse'),
                          subtitle: const Text('Vuelve a recorrerlas y confirma sus datos.'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _ir(ModeracionPage(vms: vms)),
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Ver moderación'),
                        style: OutlinedButton.styleFrom(foregroundColor: kAcento, side: const BorderSide(color: kAcento)),
                      ),
                    ),
                  ],
                );
              },
            ),
            const TituloSeccion('Rutas registradas'),
            ListenableBuilder(
              listenable: vms.catalogo,
              builder: (context, _) {
                final cat = vms.catalogo.cat;
                final rutas = [...cat.rutas]..sort((a, b) => a.nombre.compareTo(b.nombre));
                if (rutas.isEmpty) return const EstadoVacio(mensaje: 'Aún no hay rutas. Crea la primera con "Nueva ruta".');
                final ahora = DateTime.now();
                return Column(children: [
                  for (final r in rutas)
                    TarjetaRuta(
                      ruta: r,
                      estado: cat.estadoRuta(r.id, ahora),
                      detalle: r.activa ? 'Activa · ${cat.geosDeRuta(r.id).length} recorrido(s)' : 'Inactiva (no la ve el público)',
                      accion: const Icon(Icons.edit, color: kAcento),
                      alTocar: () => _ir(RutaFormPage(vms: vms, idRuta: r.id)),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Drawer _menu(BuildContext context) {
    final vms = widget.vms;
    Widget item(IconData i, String t, Widget Function() pagina) => ListTile(
          leading: Icon(i),
          title: Text(t),
          onTap: () {
            Navigator.pop(context);
            _ir(pagina());
          },
        );
    return Drawer(
      backgroundColor: kSuperficie,
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: Text(vms.sesion.perfil?.nombre ?? 'Administrador', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Administrador'),
              leading: const Icon(Icons.admin_panel_settings, color: kAcento),
            ),
            const Divider(color: kBorde),
            item(Icons.alt_route, 'Rutas, recorridos y horarios', () => RutaListaAdminPage(vms: vms)),
            item(Icons.signpost_outlined, 'Paradas', () => ParadasAdminPage(vms: vms)),
            item(Icons.place_outlined, 'Lugares y sus horarios', () => LugaresAdminPage(vms: vms)),
            item(Icons.campaign_outlined, 'Avisos de servicio', () => AvisosAdminPage(vms: vms)),
            item(Icons.event_outlined, 'Días especiales', () => CalendarioPage(vms: vms)),
            item(Icons.gavel_outlined, 'Moderación del tablón', () => ModeracionPage(vms: vms)),
            item(Icons.people_outline, 'Usuarios', () => UsuariosPage(vms: vms)),
            item(Icons.history, 'Bitácora', () => BitacoraPage(vms: vms)),
            const Divider(color: kBorde),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Ver la app como usuario'),
              onTap: () {
                Navigator.pop(context);
                vms.sesion.alternarVistaUsuario();
                irADashboard(context, vms);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de todas las rutas (activas e inactivas) para editar.
class RutaListaAdminPage extends StatelessWidget {
  final AppViewModels vms;
  const RutaListaAdminPage({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kAcento,
        onPressed: () => abrir(context, RutaFormPage(vms: vms)),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: vms.catalogo,
        builder: (context, _) {
          final cat = vms.catalogo.cat;
          final rutas = [...cat.rutas]..sort((a, b) => a.nombre.compareTo(b.nombre));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in rutas)
                TarjetaRuta(
                  ruta: r,
                  estado: cat.estadoRuta(r.id, DateTime.now()),
                  detalle: r.activa ? 'Activa' : 'Inactiva',
                  accion: const Icon(Icons.edit, color: kAcento),
                  alTocar: () => abrir(context, RutaFormPage(vms: vms, idRuta: r.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}
