import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/comunidad.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../comun/publicacion_detalle_page.dart';
import '../comun/viajes_guardados_page.dart';

/// Perfil y ajustes en un solo formulario.
/// Visitante: versión reducida (notificaciones, idioma, borrar datos, acerca de).
class PerfilPage extends StatefulWidget {
  final AppViewModels vms;
  final bool comoPestana;
  const PerfilPage({super.key, required this.vms, this.comoPestana = false});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _nombre = TextEditingController();
  Future<(int, int)>? _resumen;
  Future<List<Publicacion>>? _mias;

  @override
  void initState() {
    super.initState();
    final p = widget.vms.sesion.perfil;
    if (p != null) {
      _nombre.text = p.nombre;
      _resumen = widget.vms.sesion.repo.resumen(p.id).catchError((_) => (0, 0));
      _mias = widget.vms.comunidad.publicaciones(deUsuario: p.id, limite: 20).catchError((_) => <Publicacion>[]);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil(Perfil nuevo) async {
    try {
      await widget.vms.sesion.guardarPerfil(nuevo);
      await widget.vms.favoritos.aplicarEfectos();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<String?> _pedirTexto(String titulo, {bool oculto = false, String? Function(String?)? validar}) {
    final c = TextEditingController();
    final key = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Form(
          key: key,
          child: TextFormField(controller: c, obscureText: oculto, autofocus: true, validator: validar),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Cancelar', 'Cancel'))),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, c.text);
            },
            child: Text(tx('Guardar', 'Save')),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarCuenta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('¿Eliminar tu cuenta?', 'Delete your account?')),
        content: Text(tx(
            'Se borran tu perfil, tus rutas seguidas y tus viajes. Tus publicaciones quedan como "Usuario eliminado". No se puede deshacer.',
            'Your profile, followed routes and trips are deleted. Your posts remain as "Deleted user". This cannot be undone.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('Cancelar', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tx('Eliminar', 'Delete'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.vms.sesion.eliminarCuenta();
      if (mounted) await cerrarSesion(context, widget.vms);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: !widget.comoPestana, title: Text(vms.sesion.conSesion ? tx('Perfil y ajustes', 'Profile & settings') : tx('Ajustes', 'Settings'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([vms.sesion, vms.favoritos]),
        builder: (context, _) {
          final p = vms.sesion.perfil;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (p != null) ..._perfil(p),
              TituloSeccion(tx('Notificaciones', 'Notifications')),
              SwitchListTile(
                title: Text(tx('Avisos de las rutas que sigo', 'Notices for routes I follow')),
                value: vms.favoritos.notifRutas,
                activeTrackColor: kAcento,
                onChanged: (v) => p != null ? _guardarPerfil(p.copyWith(notifRutas: v)) : vms.favoritos.cambiarNotifVisitante(rutas: v),
              ),
              SwitchListTile(
                title: Text(tx('Avisos generales de la ciudad', 'City-wide notices')),
                value: vms.favoritos.notifGenerales,
                activeTrackColor: kAcento,
                onChanged: (v) => p != null ? _guardarPerfil(p.copyWith(notifGenerales: v)) : vms.favoritos.cambiarNotifVisitante(generales: v),
              ),
              if (p != null)
                SwitchListTile(
                  title: Text(tx('Respuestas a mis publicaciones', 'Replies to my posts')),
                  value: p.notifRespuestas,
                  activeTrackColor: kAcento,
                  onChanged: (v) => _guardarPerfil(p.copyWith(notifRespuestas: v)),
                ),
              ListTile(
                title: Text(tx('Aviso de último camión', 'Last bus alert')),
                subtitle: Text(tx('De las rutas que sigues', 'For routes you follow')),
                trailing: DropdownButton<int>(
                  value: vms.favoritos.ultimoCamionMin,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(tx('Apagado', 'Off'))),
                    for (final m in const [15, 30, 40, 60]) DropdownMenuItem(value: m, child: Text(tx('$m min antes', '$m min before'))),
                  ],
                  onChanged: (v) => vms.favoritos.cambiarUltimoCamion(v ?? 40),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bookmarks_outlined),
                title: Text(tx('Viajes guardados y recordatorios', 'Saved trips & reminders')),
                onTap: () => abrir(context, ViajesGuardadosPage(vms: vms)),
              ),
              TituloSeccion(tx('Idioma', 'Language')),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'es', label: Text('Español')), ButtonSegment(value: 'en', label: Text('English'))],
                selected: {Idioma.codigo},
                onSelectionChanged: (s) async {
                  final nuevo = s.first;
                  if (p != null) await _guardarPerfil(p.copyWith(idioma: nuevo));
                  await vms.idioma.cambiar(nuevo);
                },
              ),
              TituloSeccion(tx('Datos', 'Data')),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(tx('Borrar datos guardados en el teléfono', 'Clear data saved on this phone')),
                subtitle: Text(tx('Rutas guardadas sin conexión, rutas seguidas y viajes del visitante', 'Offline routes, followed routes and visitor trips')),
                onTap: () async {
                  await vms.favoritos.cache.borrarTodo();
                  await vms.favoritos.cargar();
                  await vms.viajes.cargar();
                  await vms.catalogo.refrescar();
                  if (context.mounted) avisar(context, tx('Datos borrados y rutas descargadas de nuevo', 'Data cleared and routes downloaded again'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(tx('Acerca de y privacidad', 'About & privacy')),
                onTap: () => _acercaDe(context),
              ),
              const SizedBox(height: 8),
              if (p != null) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kSuperficie, padding: const EdgeInsets.all(14)),
                  onPressed: () => cerrarSesion(context, vms),
                  icon: const Icon(Icons.logout),
                  label: Text(tx('Cerrar sesión', 'Sign out')),
                ),
                TextButton(
                  onPressed: _eliminarCuenta,
                  child: Text(tx('Eliminar mi cuenta', 'Delete my account'), style: const TextStyle(color: Colors.redAccent)),
                ),
              ] else
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(14)),
                  onPressed: () => cerrarSesion(context, vms),
                  icon: const Icon(Icons.login),
                  label: Text(tx('Iniciar sesión o crear cuenta', 'Sign in or create account')),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _perfil(Perfil p) {
    final vms = widget.vms;
    return [
      Row(children: [
        CircleAvatar(radius: 30, backgroundColor: kAcento, child: Text(p.nombre.characters.first.toUpperCase(), style: const TextStyle(fontSize: 26, color: Colors.white))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(vms.sesion.repo.usuarioActual?.email ?? '', style: const TextStyle(color: kTextoSecundario)),
            if (p.rol == Rol.admin) Text(tx('Administrador', 'Administrator'), style: const TextStyle(color: kAcento)),
            if (p.suspendido) Text(tx('Cuenta suspendida', 'Account suspended'), style: const TextStyle(color: Colors.redAccent)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      FutureBuilder<(int, int)>(
        future: _resumen,
        builder: (context, s) {
          final (pubs, utiles) = s.data ?? (0, 0);
          return Row(children: [
            Expanded(child: TarjetaMetrica(icono: Icons.forum_outlined, valor: '$pubs', etiqueta: tx('Publicaciones', 'Posts'))),
            const SizedBox(width: 10),
            Expanded(child: TarjetaMetrica(icono: Icons.thumb_up_outlined, valor: '$utiles', etiqueta: tx('"Útil" recibidos', '"Helpful" received'))),
          ]);
        },
      ),
      if (p.rol == Rol.admin)
        SwitchListTile(
          title: Text(tx('Ver la app como usuario', 'View app as a user')),
          value: vms.sesion.vistaUsuario,
          activeTrackColor: kAcento,
          onChanged: (_) {
            vms.sesion.alternarVistaUsuario();
            irADashboard(context, vms);
          },
        ),
      TituloSeccion(tx('Cuenta', 'Account')),
      ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(tx('Cambiar nombre', 'Change name')),
        subtitle: Text(p.nombre),
        onTap: () async {
          final n = await _pedirTexto(tx('Nuevo nombre', 'New name'), validar: Validadores.nombre);
          if (n != null) await _guardarPerfil(p.copyWith(nombre: n.trim()));
        },
      ),
      ListTile(
        leading: const Icon(Icons.email_outlined),
        title: Text(tx('Cambiar correo', 'Change email')),
        onTap: () async {
          final c = await _pedirTexto(tx('Nuevo correo', 'New email'), validar: Validadores.correo);
          if (c == null) return;
          try {
            await vms.sesion.repo.cambiarCorreo(c);
            if (mounted) avisar(context, tx('Revisa tu nuevo correo para confirmar el cambio.', 'Check your new email to confirm the change.'));
          } catch (e) {
            if (mounted) avisar(context, mensajeError(e));
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(tx('Cambiar contraseña', 'Change password')),
        onTap: () async {
          final c = await _pedirTexto(tx('Nueva contraseña', 'New password'), oculto: true, validar: Validadores.contrasena);
          if (c == null) return;
          try {
            await vms.sesion.repo.cambiarContrasena(c);
            if (mounted) avisar(context, tx('Contraseña actualizada', 'Password updated'));
          } catch (e) {
            if (mounted) avisar(context, mensajeError(e));
          }
        },
      ),
      TituloSeccion(tx('Mis publicaciones', 'My posts')),
      FutureBuilder<List<Publicacion>>(
        future: _mias,
        builder: (context, s) {
          if (!s.hasData) return const Cargando();
          if (s.data!.isEmpty) return Text(tx('Aún no publicas nada.', "You haven't posted yet."), style: const TextStyle(color: kTextoSecundario));
          return Column(children: [
            for (final pub in s.data!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(pub.categoria.icono),
                title: Text(pub.texto, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(pub.oculta ? tx('Oculta por moderación', 'Hidden by moderation') : '${pub.utiles} ${tx('útil', 'helpful')} · ${pub.comentarios} ${tx('comentarios', 'comments')}'),
                onTap: () => abrir(context, PublicacionDetallePage(vms: vms, idPublicacion: pub.id)),
              ),
          ]);
        },
      ),
    ];
  }

  void _acercaDe(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camiones Dolores'),
        content: SingleChildScrollView(
          child: Text(tx(
            'Sistema de Información de Transporte de Dolores Hidalgo.\n\n'
                'Fuentes: rutas, paradas y horarios capturados en campo por la administración; tarifas del concesionario o municipio; horarios de lugares de cada institución. Los tiempos son rangos, no predicciones.\n\n'
                'Mapa: © colaboradores de OpenStreetMap. Rutas a pie: openrouteservice.org. Direcciones: Nominatim.\n\n'
                'Privacidad: solo guardamos tu nombre y correo. Tu ubicación se usa únicamente en tu teléfono y nunca se envía al servidor. Puedes eliminar tu cuenta cuando quieras (Ley Federal de Protección de Datos Personales en Posesión de los Particulares).',
            'Transit Information System for Dolores Hidalgo.\n\n'
                'Sources: routes, stops and schedules surveyed in the field by the administration; fares from the operator or municipality; place schedules from each institution. Times are ranges, not predictions.\n\n'
                'Map: © OpenStreetMap contributors. Walking routes: openrouteservice.org. Addresses: Nominatim.\n\n'
                'Privacy: we only store your name and email. Your location is used only on your phone and is never sent to the server. You can delete your account at any time.',
          )),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}
