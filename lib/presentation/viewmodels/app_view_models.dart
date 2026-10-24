import 'inicio_view_model.dart';
import 'reportes_view_model.dart';
import 'rutas_admin_view_model.dart';
import 'sesion_view_model.dart';

/// Agrupa los ViewModels para pasarlos juntos entre pantallas.
class AppViewModels {
  final InicioViewModel inicio;
  final SesionViewModel sesion;
  final ReportesViewModel reportes;
  final RutasAdminViewModel rutasAdmin;

  const AppViewModels({
    required this.inicio,
    required this.sesion,
    required this.reportes,
    required this.rutasAdmin,
  });
}
