import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/validadores.dart';
import '../navigation/navegacion.dart';
import '../viewmodels/app_view_models.dart';
import '../widgets/campo_texto.dart';
import 'registro_page.dart';

class LoginPage extends StatefulWidget {
  final AppViewModels vms;

  const LoginPage({super.key, required this.vms});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _ocultar = true;
  String? _errorGeneral;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _entrar() {
    if (!_formKey.currentState!.validate()) return;
    final ok = widget.vms.sesion.iniciarSesion(_correo.text, _contrasena.text);
    if (!ok) {
      setState(() => _errorGeneral = 'Correo o contraseña incorrectos');
      return;
    }
    irADashboard(context, widget.vms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.directions_bus, size: 64, color: kAcento),
                  const SizedBox(height: 12),
                  const Text(
                    'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 28),
                  CampoTexto(
                    controller: _correo,
                    etiqueta: 'Correo',
                    icono: Icons.email_outlined,
                    teclado: TextInputType.emailAddress,
                    validator: Validadores.correo,
                  ),
                  const SizedBox(height: 14),
                  CampoTexto(
                    controller: _contrasena,
                    etiqueta: 'Contraseña',
                    icono: Icons.lock_outline,
                    oculto: _ocultar,
                    validator: Validadores.contrasena,
                    sufijo: IconButton(
                      icon: Icon(
                        _ocultar ? Icons.visibility_off : Icons.visibility,
                        color: kTextoSecundario,
                      ),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    ),
                  ),
                  if (_errorGeneral != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorGeneral!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _entrar,
                    style: FilledButton.styleFrom(
                      backgroundColor: kAcento,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Entrar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegistroPage(vms: widget.vms),
                      ),
                    ),
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Demo: admin@camiones.com · alumno@camiones.com · '
                    'visitante@camiones.com (contraseña 123456)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: kTextoSecundario),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
