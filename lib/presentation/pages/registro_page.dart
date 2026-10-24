import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/validadores.dart';
import '../../domain/entities/usuario.dart';
import '../navigation/navegacion.dart';
import '../viewmodels/app_view_models.dart';
import '../widgets/campo_texto.dart';

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
  Rol? _rol;
  String? _errorGeneral;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _registrar() {
    if (!_formKey.currentState!.validate()) return;
    final ok = widget.vms.sesion.registrar(
      nombre: _nombre.text,
      correo: _correo.text,
      contrasena: _contrasena.text,
      rol: _rol!,
    );
    if (!ok) {
      setState(() => _errorGeneral = 'Ese correo ya está registrado');
      return;
    }
    irADashboard(context, widget.vms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: kFondo,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoTexto(
                  controller: _nombre,
                  etiqueta: 'Nombre',
                  icono: Icons.person_outline,
                  validator: (v) => Validadores.requerido(v, 'El nombre'),
                ),
                const SizedBox(height: 14),
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
                  oculto: true,
                  validator: Validadores.contrasena,
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  controller: _confirmar,
                  etiqueta: 'Confirmar contraseña',
                  icono: Icons.lock_outline,
                  oculto: true,
                  validator: (v) => v != _contrasena.text
                      ? 'Las contraseñas no coinciden'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Rol>(
                  initialValue: _rol,
                  dropdownColor: kSuperficie,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Tipo de usuario',
                    labelStyle: const TextStyle(color: kTextoSecundario),
                    prefixIcon:
                        const Icon(Icons.badge_outlined, color: kAcento),
                    filled: true,
                    fillColor: kSuperficie,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kBorde),
                    ),
                  ),
                  items: [
                    for (final r in Rol.values)
                      DropdownMenuItem(value: r, child: Text(r.etiqueta)),
                  ],
                  onChanged: (r) => setState(() => _rol = r),
                  validator: (r) => r == null ? 'Selecciona un tipo' : null,
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
                  onPressed: _registrar,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Registrarme'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
