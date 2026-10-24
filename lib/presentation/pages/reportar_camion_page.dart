import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/reporte.dart';
import '../viewmodels/reportes_view_model.dart';
import '../widgets/campo_texto.dart';

/// Formulario para reportar el paso de un camión (alumno y visitante).
class ReportarCamionPage extends StatefulWidget {
  final ReportesViewModel viewModel;

  const ReportarCamionPage({super.key, required this.viewModel});

  @override
  State<ReportarCamionPage> createState() => _ReportarCamionPageState();
}

class _ReportarCamionPageState extends State<ReportarCamionPage> {
  static const _rutas = [
    'Centro – UTNG',
    'Col. Cruz Blanca – Centro',
    'Terminal – UTNG',
  ];
  static const _paradas = [
    'Parada Plaza Principal',
    'Parada Av. Hidalgo',
    'Parada Central Camionera',
  ];
  static const _tipos = ['Ya pasó', 'Viene lleno', 'No ha pasado'];

  final _formKey = GlobalKey<FormState>();
  final _comentario = TextEditingController();
  String? _ruta;
  String? _parada;
  String? _tipo;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  String? _validarComentario(String? v) {
    if (v != null && v.trim().length > 140) return 'Máximo 140 caracteres';
    return null;
  }

  void _enviar() {
    if (!_formKey.currentState!.validate()) return;
    widget.viewModel.agregar(Reporte(
      ruta: _ruta!,
      parada: _parada!,
      tipo: _tipo!,
      comentario: _comentario.text.trim(),
      hora: DateTime.now(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte enviado')),
    );
    Navigator.of(context).pop();
  }

  Widget _selector({
    required String etiqueta,
    required IconData icono,
    required List<String> opciones,
    required String? valor,
    required ValueChanged<String?> alCambiar,
    required String mensajeError,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      dropdownColor: kSuperficie,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: kTextoSecundario),
        prefixIcon: Icon(icono, color: kAcento),
        filled: true,
        fillColor: kSuperficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorde),
        ),
      ),
      items: [
        for (final o in opciones) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: alCambiar,
      validator: (v) => v == null ? mensajeError : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar camión'),
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
                _selector(
                  etiqueta: 'Ruta',
                  icono: Icons.alt_route,
                  opciones: _rutas,
                  valor: _ruta,
                  alCambiar: (v) => setState(() => _ruta = v),
                  mensajeError: 'Selecciona una ruta',
                ),
                const SizedBox(height: 14),
                _selector(
                  etiqueta: 'Parada',
                  icono: Icons.place_outlined,
                  opciones: _paradas,
                  valor: _parada,
                  alCambiar: (v) => setState(() => _parada = v),
                  mensajeError: 'Selecciona una parada',
                ),
                const SizedBox(height: 14),
                _selector(
                  etiqueta: '¿Qué pasó con el camión?',
                  icono: Icons.directions_bus_outlined,
                  opciones: _tipos,
                  valor: _tipo,
                  alCambiar: (v) => setState(() => _tipo = v),
                  mensajeError: 'Selecciona el tipo de reporte',
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  controller: _comentario,
                  etiqueta: 'Comentario (opcional)',
                  icono: Icons.chat_bubble_outline,
                  validator: (v) => _validarComentario(v),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _enviar,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}