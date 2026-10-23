import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Campo de formulario con el estilo oscuro de la app.
class CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String etiqueta;
  final IconData icono;
  final String? Function(String?)? validator;
  final bool oculto;
  final TextInputType? teclado;
  final Widget? sufijo;

  const CampoTexto({
    super.key,
    required this.controller,
    required this.etiqueta,
    required this.icono,
    this.validator,
    this.oculto = false,
    this.teclado,
    this.sufijo,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: controller,
      obscureText: oculto,
      keyboardType: teclado,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: kTextoSecundario),
        prefixIcon: Icon(icono, color: kAcento),
        suffixIcon: sufijo,
        filled: true,
        fillColor: kSuperficie,
        enabledBorder: borde(kBorde),
        focusedBorder: borde(kAcento),
        errorBorder: borde(Colors.redAccent),
        focusedErrorBorder: borde(Colors.redAccent),
      ),
    );
  }
}
