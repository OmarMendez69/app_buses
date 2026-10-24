import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/validadores.dart';
import '../../domain/entities/ruta.dart';
import '../viewmodels/rutas_admin_view_model.dart';
import '../widgets/campo_texto.dart';
import '../widgets/tarjeta_ruta_admin.dart';

/// Formulario del administrador: agrega una ruta o edita una existente.
class FormularioRutaPage extends StatefulWidget {
  final RutasAdminViewModel viewModel;

  /// Si es null se crea una ruta nueva; si no, se edita.
  final Ruta? ruta;

  const FormularioRutaPage({super.key, required this.viewModel, this.ruta});

  @override
  State<FormularioRutaPage> createState() => _FormularioRutaPageState();
}

class _FormularioRutaPageState extends State<FormularioRutaPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _frecuencia;
  String? _color;
  late bool _activa;

  bool get _editando => widget.ruta != null;

  @override
  void initState() {
    super.initState();
    final r = widget.ruta;
    _nombre = TextEditingController(text: r?.nombre ?? '');
    _frecuencia = TextEditingController(
      text: r == null ? '' : '${r.frecuenciaAproxMin}',
    );
    _color = r?.color;
    _activa = r?.activa ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _frecuencia.dispose();
    super.dispose();
  }

  String? _validarNombre(String? v) {
    final error = Validadores.requerido(v, 'El nombre');
    if (error != null) return error;
    if (widget.viewModel.existeNombre(v!, exceptoId: widget.ruta?.id)) {
      return 'Ya existe una ruta con ese nombre';
    }
    return null;
  }

  String? _validarFrecuencia(String? v) {
    final error = Validadores.requerido(v, 'La frecuencia');
    if (error != null) return error;
    final n = int.tryParse(v!.trim());
    if (n == null || n < 1 || n > 120) return 'Escribe minutos entre 1 y 120';
    return null;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final frecuencia = int.parse(_frecuencia.text.trim());
    if (_editando) {
      widget.viewModel.actualizar(widget.ruta!.copyWith(
        nombre: _nombre.text.trim(),
        color: _color,
        frecuenciaAproxMin: frecuencia,
        activa: _activa,
      ));
    } else {
      widget.viewModel.agregar(
        nombre: _nombre.text,
        color: _color!,
        frecuenciaAproxMin: frecuencia,
        activa: _activa,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_editando ? 'Ruta actualizada' : 'Ruta agregada')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar ruta' : 'Nueva ruta'),
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
                  etiqueta: 'Nombre (ej. Centro – UTNG)',
                  icono: Icons.alt_route,
                  validator: _validarNombre,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _color,
                  dropdownColor: kSuperficie,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Color en el mapa',
                    labelStyle: const TextStyle(color: kTextoSecundario),
                    prefixIcon: const Icon(Icons.palette_outlined, color: kAcento),
                    filled: true,
                    fillColor: kSuperficie,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kBorde),
                    ),
                  ),
                  items: [
                    for (final c in coloresRuta)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (c) => setState(() => _color = c),
                  validator: (c) => c == null ? 'Selecciona un color' : null,
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  controller: _frecuencia,
                  etiqueta: 'Frecuencia aproximada (minutos)',
                  icono: Icons.timer_outlined,
                  teclado: TextInputType.number,
                  validator: _validarFrecuencia,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kAcento,
                  title: const Text('Ruta activa'),
                  subtitle: const Text(
                    'Desactívala para ocultarla sin borrar su historial',
                    style: TextStyle(fontSize: 12, color: kTextoSecundario),
                  ),
                  value: _activa,
                  onChanged: (v) => setState(() => _activa = v),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_editando ? 'Guardar cambios' : 'Agregar ruta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
