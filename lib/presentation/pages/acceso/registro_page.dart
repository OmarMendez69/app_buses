import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Registro sin selector de tipo: toda cuenta nueva es "Usuario".
/// El rol de administrador solo lo asigna otro administrador.
class RegistroPage extends StatefulWidget {
  final AppViewModels vms;
  const RegistroPage({super.key, required this.vms});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final listo = await widget.vms.sesion.registrar(_nombre.text, _correo.text, _contrasena.text);
      if (!mounted) return;
      if (listo) {
        await irADashboard(context, widget.vms);
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(tx('Confirma tu correo', 'Confirm your email')),
            content: Text(tx('Te enviamos un enlace a ${_correo.text.trim()}. Ábrelo y después inicia sesión.',
                'We sent a link to ${_correo.text.trim()}. Open it and then sign in.')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx('Crear cuenta', 'Create account'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CampoTexto(controller: _nombre, etiqueta: tx('Nombre', 'Name'), icono: Icons.person_outline, validator: Validadores.nombre),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    CampoTexto(
                      controller: _confirmar,
                      etiqueta: tx('Confirmar contraseña', 'Confirm password'),
                      icono: Icons.lock_outline,
                      oculto: _ocultar,
                      validator: (v) => v != _contrasena.text ? tx('Las contraseñas no coinciden', "Passwords don't match") : null,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _enviando ? null : _registrar,
                      style: FilledButton.styleFrom(
                        backgroundColor: kAcento,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _enviando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tx('Registrarme', 'Sign up')),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tx('Solo guardamos tu nombre y tu correo. Tu ubicación nunca sale de tu teléfono.',
                          'We only store your name and email. Your location never leaves your phone.'),
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
