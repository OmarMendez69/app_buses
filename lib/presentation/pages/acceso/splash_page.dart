import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import 'login_page.dart';

/// Muestra el logotipo mientras recupera la sesión y descarga o actualiza el catálogo.
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
    _arrancar();
  }

  Future<void> _arrancar() async {
    final vms = widget.vms;
    final minimo = Future.delayed(const Duration(milliseconds: 1200));
    final catalogo = vms.catalogo.iniciar().timeout(const Duration(seconds: 8), onTimeout: () {});
    final conSesion = await vms.sesion.restaurar();
    await Future.wait([minimo, catalogo]);
    if (!mounted) return;
    if (conSesion) {
      await irADashboard(context, vms);
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage(vms: vms)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bus, size: 96, color: kAcento),
            const SizedBox(height: 16),
            const Text('Camiones Dolores', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              tx('Qué camión tomar, dónde y cada cuánto pasa', 'Which bus to take, where and how often'),
              style: const TextStyle(color: kTextoSecundario),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: kAcento),
          ],
        ),
      ),
    );
  }
}
