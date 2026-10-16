import 'package:flutter/material.dart';

import 'app.dart';
import 'data/datasources/rutas_data_source.dart';
import 'data/datasources/rutas_mock_data_source.dart';
import 'data/repositories/rutas_repository_impl.dart';
import 'domain/repositories/rutas_repository.dart';
import 'domain/usecases/obtener_rutas_cercanas.dart';
import 'presentation/viewmodels/inicio_view_model.dart';

/// Inyección de dependencias: aquí se arman las capas.
void main() {
  // Data
  final RutasDataSource fuente = RutasMockDataSource();
  final RutasRepository repositorio = RutasRepositoryImpl(fuente);

  // Domain
  final obtenerRutasCercanas = ObtenerRutasCercanas(repositorio);

  // Presentation
  final inicioViewModel = InicioViewModel(obtenerRutasCercanas);

  runApp(CamionesApp(inicioViewModel: inicioViewModel));
}
