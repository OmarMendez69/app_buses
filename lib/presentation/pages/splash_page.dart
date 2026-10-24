import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/app_view_models.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  final AppViewModels vms;

  const SplashPage({super.key, required this.vms});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Tip captura: sube a 10 segundos para tomar el screenshot y regrésalo a 2.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginPage(vms: widget.vms)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_bus, size: 96, color: kAcento),
            SizedBox(height: 16),
            Text(
              'Camiones Dolores',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Tu ruta, en tiempo real',
              style: TextStyle(color: kTextoSecundario),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: kAcento),
          ],
        ),
      ),
    );
  }
}
