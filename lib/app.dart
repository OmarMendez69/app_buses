import 'package:flutter/material.dart';

import 'core/app_colors.dart';
import 'core/idioma.dart';
import 'presentation/pages/acceso/splash_page.dart';
import 'presentation/viewmodels/app_view_models.dart';

class CamionesApp extends StatelessWidget {
  final AppViewModels vms;

  const CamionesApp({super.key, required this.vms});

  @override
  Widget build(BuildContext context) {
    // Al cambiar de idioma se reconstruye toda la app.
    return ListenableBuilder(
      listenable: vms.idioma,
      builder: (context, _) => MaterialApp(
        key: ValueKey(Idioma.codigo),
        title: 'Camiones Dolores',
        debugShowCheckedModeBanner: false,
        theme: temaApp(),
        home: SplashPage(vms: vms),
      ),
    );
  }
}
