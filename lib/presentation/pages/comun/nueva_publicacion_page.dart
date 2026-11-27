import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/comunidad.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Nueva publicación del tablón (sustituye a "Reportar camión").
/// La fecha y hora se registran solas; la ubicación no se guarda.
class NuevaPublicacionPage extends StatefulWidget {
  final AppViewModels vms;
  final int? idRutaInicial;

  /// Desde el tablón (pestaña Comunidad) solo se ofrecen pregunta, objeto perdido y general;
  /// los reportes tienen su propia hoja rápida.
  final bool soloComunidad;
  const NuevaPublicacionPage({super.key, required this.vms, this.idRutaInicial, this.soloComunidad = false});

  @override
  State<NuevaPublicacionPage> createState() => _NuevaPublicacionPageState();
}

class _NuevaPublicacionPageState extends State<NuevaPublicacionPage> {
  final _formKey = GlobalKey<FormState>();
  final _texto = TextEditingController();
  CategoriaPublicacion _categoria = CategoriaPublicacion.general;
  int? _ruta;
  int? _parada;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _ruta = widget.idRutaInicial;
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await widget.vms.comunidad.publicar(_categoria, _texto.text, idRuta: _ruta, idParada: _parada);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final paradas = _ruta == null
        ? cat.paradasActivas
        : cat.paradasActivas.where((p) => cat.rutasDeParada(p.id).any((r) => r.$1.id == _ruta)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tx('Nueva publicación', 'New post'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TituloSeccion(tx('Categoría', 'Category')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in (widget.soloComunidad ? CategoriaPublicacion.comunidad : CategoriaPublicacion.values))
                  ChoiceChip(
                    avatar: Icon(c.icono, size: 16),
                    label: Text(c.etiqueta),
                    selected: _categoria == c,
                    onSelected: (_) => setState(() => _categoria = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            CampoTexto(
              controller: _texto,
              etiqueta: tx('¿Qué quieres compartir?', 'What do you want to share?'),
              icono: Icons.edit_outlined,
              lineas: 4,
              maximo: 500,
              validator: (v) => (v == null || v.trim().length < 3) ? tx('Escribe al menos 3 caracteres', 'Write at least 3 characters') : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _ruta,
              decoration: InputDecoration(labelText: tx('Ruta (opcional)', 'Route (optional)'), filled: true, fillColor: kSuperficie),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(tx('Ninguna', 'None'))),
                for (final r in cat.rutasActivas) DropdownMenuItem<int?>(value: r.id, child: Text(r.nombre)),
              ],
              onChanged: (v) => setState(() {
                _ruta = v;
                _parada = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey(_ruta),
              initialValue: _parada,
              isExpanded: true,
              decoration: InputDecoration(labelText: tx('Parada (opcional)', 'Stop (optional)'), filled: true, fillColor: kSuperficie),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(tx('Ninguna', 'None'))),
                for (final p in paradas) DropdownMenuItem<int?>(value: p.id, child: Text(p.nombre, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _parada = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
              onPressed: _enviando ? null : _publicar,
              child: Text(tx('Publicar', 'Post')),
            ),
            const SizedBox(height: 10),
            Text(
              tx('Lo que publicas es comunitario: lo ven todos, pero no cambia rutas ni horarios. Máximo 5 publicaciones por hora.',
                  'Posts are community content: everyone sees them, but they do not change routes or schedules. Max 5 posts per hour.'),
              style: const TextStyle(color: kTextoSecundario, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
