import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/viewmodels/app_view_models.dart';

class CamionesApp extends StatelessWidget {
  final AppViewModels vms;

  const CamionesApp({super.key, required this.vms});

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
      home: SplashPage(vms: vms),
    );
  }
}
