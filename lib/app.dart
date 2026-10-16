import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'presentation/pages/inicio_page.dart';
import 'presentation/viewmodels/inicio_view_model.dart';

class CamionesApp extends StatelessWidget {
  final InicioViewModel inicioViewModel;

  const CamionesApp({super.key, required this.inicioViewModel});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camiones Dolores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kFondo,
        colorScheme: const ColorScheme.dark(primary: kAcento),
        useMaterial3: true,
      ),
      home: InicioPage(viewModel: inicioViewModel),
    );
  }
}
