import 'package:flutter/material.dart';

import '../../domain/entities/comunidad.dart';
import '../pages/acceso/login_page.dart';
import '../pages/admin/admin_shell.dart';
import '../pages/usuario/usuario_shell.dart';
import '../pages/visitante/visitante_shell.dart';
import '../viewmodels/app_view_models.dart';

/// Cada perfil tiene su propio dashboard.
Widget dashboardPorRol(AppViewModels vms) {
  switch (vms.sesion.rol) {
    case Rol.admin:
      return AdminShell(vms: vms);
    case Rol.usuario:
      return UsuarioShell(vms: vms);
    case Rol.visitante:
      return VisitanteShell(vms: vms);
  }
}

/// Lleva al dashboard del perfil actual (borra el historial).
Future<void> irADashboard(BuildContext context, AppViewModels vms) async {
  // Favoritos y viajes dependen de si hay cuenta o no.
  vms.favoritos.cargar();
  vms.viajes.cargar();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => dashboardPorRol(vms)),
    (_) => false,
  );
}

Future<void> cerrarSesion(BuildContext context, AppViewModels vms) async {
  await vms.seguimiento.detener();
  await vms.sesion.cerrarSesion();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => LoginPage(vms: vms)),
    (_) => false,
  );
}

void abrir(BuildContext context, Widget pagina) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));

void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
