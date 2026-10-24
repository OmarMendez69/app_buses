import 'package:flutter/material.dart';

import 'app.dart';
import 'data/datasources/rutas_data_source.dart';
import 'data/datasources/rutas_mock_data_source.dart';
import 'data/repositories/rutas_repository_impl.dart';
import 'domain/repositories/rutas_repository.dart';
import 'domain/usecases/obtener_rutas_cercanas.dart';
import 'presentation/viewmodels/app_view_models.dart';
import 'presentation/viewmodels/inicio_view_model.dart';
import 'presentation/viewmodels/reportes_view_model.dart';
import 'presentation/viewmodels/rutas_admin_view_model.dart';
import 'presentation/viewmodels/sesion_view_model.dart';

/// Inyección de dependencias: aquí se arman las capas.
void main() {
  // Data
  final RutasDataSource fuente = RutasMockDataSource();
  final RutasRepository repositorio = RutasRepositoryImpl(fuente);

  // Domain
  final obtenerRutasCercanas = ObtenerRutasCercanas(repositorio);

  // Presentation (un solo juego de ViewModels vive toda la app: así el estado persiste)
  final vms = AppViewModels(
    inicio: InicioViewModel(obtenerRutasCercanas),
    sesion: SesionViewModel(),
    reportes: ReportesViewModel(),
    rutasAdmin: RutasAdminViewModel(),
  );

  runApp(CamionesApp(vms: vms));
}
