import 'package:flutter/material.dart';

import '../../domain/entities/usuario.dart';
import '../pages/dashboard_admin_page.dart';
import '../pages/dashboard_visitante_page.dart';
import '../pages/inicio_page.dart';
import '../pages/login_page.dart';
import '../viewmodels/app_view_models.dart';

/// Cada rol tiene su propio dashboard.
Widget dashboardPorRol(Rol rol, AppViewModels vms) {
  switch (rol) {
    case Rol.admin:
      return DashboardAdminPage(vms: vms);
    case Rol.visitante:
      return DashboardVisitantePage(vms: vms);
    case Rol.alumno:
      return InicioPage(vms: vms);
  }
}

/// Lleva al dashboard del usuario que inició sesión (borra el historial).
void irADashboard(BuildContext context, AppViewModels vms) {
  final rol = vms.sesion.rol;
  if (rol == null) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => dashboardPorRol(rol, vms)),
    (_) => false,
  );
}

void cerrarSesion(BuildContext context, AppViewModels vms) {
  vms.sesion.cerrarSesion();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => LoginPage(vms: vms)),
    (_) => false,
  );
}
