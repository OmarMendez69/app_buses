import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
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
  bool _enviando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });
    try {
      await widget.vms.sesion.iniciarSesion(_correo.text, _contrasena.text);
      if (mounted) await irADashboard(context, widget.vms);
    } catch (e) {
      setState(() => _errorGeneral = mensajeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _visitante() async {
    await widget.vms.sesion.entrarComoVisitante();
    if (mounted) await irADashboard(context, widget.vms);
  }

  Future<void> _recuperar() async {
    final error = Validadores.correo(_correo.text);
    if (error != null) {
      avisar(context, tx('Escribe tu correo arriba y vuelve a tocar "Recuperar".', 'Type your email above and tap "Recover" again.'));
      return;
    }
    try {
      await widget.vms.sesion.repo.recuperar(_correo.text);
      if (mounted) avisar(context, tx('Te enviamos un correo para cambiar tu contraseña.', 'We sent you an email to reset your password.'));
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => widget.vms.idioma.cambiar(Idioma.codigo == 'es' ? 'en' : 'es'),
                        child: Text(Idioma.codigo == 'es' ? 'English' : 'Español'),
                      ),
                    ),
                    const Icon(Icons.directions_bus, size: 64, color: kAcento),
                    const SizedBox(height: 12),
                    Text(tx('Iniciar sesión', 'Sign in'),
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 28),
                    CampoTexto(
                      controller: _correo,
                      etiqueta: tx('Correo', 'Email'),
                      icono: Icons.email_outlined,
                      teclado: TextInputType.emailAddress,
                      validator: Validadores.correo,
                    ),
                    const SizedBox(height: 14),
                    CampoTexto(
                      controller: _contrasena,
                      etiqueta: tx('Contraseña', 'Password'),
                      icono: Icons.lock_outline,
                      oculto: _ocultar,
                      validator: Validadores.contrasena,
                      sufijo: IconButton(
                        icon: Icon(_ocultar ? Icons.visibility_off : Icons.visibility, color: kTextoSecundario),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _recuperar, child: Text(tx('Recuperar contraseña', 'Recover password'))),
                    ),
                    if (_errorGeneral != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_errorGeneral!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    FilledButton(
                      onPressed: _enviando ? null : _entrar,
                      style: FilledButton.styleFrom(
                        backgroundColor: kAcento,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _enviando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tx('Entrar', 'Sign in')),
                    ),
                    TextButton(
                      onPressed: () => abrir(context, RegistroPage(vms: widget.vms)),
                      child: Text(tx('¿No tienes cuenta? Regístrate', "Don't have an account? Sign up")),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: kBorde),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _visitante,
                      icon: const Icon(Icons.travel_explore),
                      label: Text(tx('Entrar como visitante', 'Continue as visitor')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: kBorde),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tx('Consulta rutas, planea viajes y lee el tablón sin crear cuenta.',
                          'Browse routes, plan trips and read the board without an account.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: kTextoSecundario),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
