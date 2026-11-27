import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../core/validadores.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import 'editor_recorrido_page.dart';
import 'horario_page.dart';

const _paleta = [
  '#E53935', '#D81B60', '#8E24AA', '#3949AB', '#1E88E5', '#00ACC1',
  '#00897B', '#43A047', '#7CB342', '#FDD835', '#FB8C00', '#6D4C41',
];

const _fuentes = {
  'concesionario': 'Concesionario',
  'municipio': 'Municipio',
  'oficial': 'Oficial',
  'levantamiento': 'Levantamiento en campo',
};

/// Formulario de ruta + sus recorridos (ida, vuelta o circuito) y horarios.
/// Las rutas se desactivan, nunca se borran (se conserva el historial).
class RutaFormPage extends StatefulWidget {
  final AppViewModels vms;
  final int? idRuta;
  const RutaFormPage({super.key, required this.vms, this.idRuta});

  @override
  State<RutaFormPage> createState() => _RutaFormPageState();
}

class _RutaFormPageState extends State<RutaFormPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _tarifa = TextEditingController();
  final _tarifaEst = TextEditingController();
  final _tarifaInapam = TextEditingController();
  final _letrero = TextEditingController();
  final _descripcion = TextEditingController();
  final _concesionario = TextEditingController();
  String _color = _paleta.first;
  String? _fuenteTarifas;
  bool _activa = false;
  String? _foto;
  int? _id;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _id = widget.idRuta;
    final r = _id == null ? null : widget.vms.catalogo.cat.rutaPorId[_id];
    if (r != null) {
      _nombre.text = r.nombre;
      _tarifa.text = r.tarifa.toStringAsFixed(2);
      _tarifaEst.text = r.tarifaEstudiante?.toStringAsFixed(2) ?? '';
      _tarifaInapam.text = r.tarifaInapam?.toStringAsFixed(2) ?? '';
      _letrero.text = r.letrero ?? '';
      _descripcion.text = r.descripcionUnidad ?? '';
      _concesionario.text = r.concesionario ?? '';
      _color = r.color.toUpperCase();
      _fuenteTarifas = r.fuenteTarifas;
      _activa = r.activa;
      _foto = r.fotoUnidad;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _tarifa, _tarifaEst, _tarifaInapam, _letrero, _descripcion, _concesionario]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => c.text.trim().isEmpty ? null : double.tryParse(c.text.replaceAll(',', '.'));
  String? _txt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final hayPreferenciales = _num(_tarifaEst) != null || _num(_tarifaInapam) != null;
    if (hayPreferenciales && _fuenteTarifas == null) {
      avisar(context, 'Indica la fuente de las tarifas preferenciales.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final id = await widget.vms.admin.guardarRuta({
        'nombre': _nombre.text.trim(),
        'color': _color,
        'tarifa': _num(_tarifa),
        'tarifa_estudiante': _num(_tarifaEst),
        'tarifa_inapam': _num(_tarifaInapam),
        'fuente_tarifas': hayPreferenciales ? _fuenteTarifas : null,
        'letrero': _txt(_letrero),
        'descripcion_unidad': _txt(_descripcion),
        'concesionario': _txt(_concesionario),
        'foto_unidad': _foto,
        'activa': _activa,
      }, id: _id);
      _id = id;
      await widget.vms.catalogo.refrescar();
      if (mounted) avisar(context, 'Ruta guardada');
      setState(() {});
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirFoto() async {
    if (_id == null) {
      avisar(context, 'Guarda la ruta primero.');
      return;
    }
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 70);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (bytes.length > 300 * 1024) {
      if (mounted) avisar(context, 'La foto pesa más de 300 KB aun comprimida. Elige otra.');
      return;
    }
    try {
      final url = await widget.vms.admin.subirFoto(_id!, bytes);
      setState(() => _foto = url);
      await widget.vms.admin.guardarRuta({'foto_unidad': url}, id: _id);
      if (mounted) avisar(context, 'Foto subida');
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _agregarRecorrido(Sentido s) async {
    try {
      await widget.vms.admin.crearRecorrido(_id!, s);
      await widget.vms.catalogo.refrescar();
      setState(() {});
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_id == null ? 'Nueva ruta' : 'Editar ruta')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _pasos(),
            CampoTexto(controller: _nombre, etiqueta: 'Nombre (ej. Centro – UTNG)', icono: Icons.alt_route, validator: Validadores.requerido, maximo: 80),
            const TituloSeccion('Color en el mapa'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _paleta)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colorDesdeHex(c),
                    child: _color == c ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                ),
            ]),
            const TituloSeccion('Tarifas'),
            CampoTexto(controller: _tarifa, etiqueta: 'Tarifa general (\$)', icono: Icons.payments_outlined, teclado: TextInputType.number, validator: (v) => Validadores.numero(v, max: 200)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: CampoTexto(controller: _tarifaEst, etiqueta: 'Estudiante', icono: Icons.school_outlined, teclado: TextInputType.number, validator: Validadores.numeroOpcional)),
              const SizedBox(width: 10),
              Expanded(child: CampoTexto(controller: _tarifaInapam, etiqueta: 'INAPAM', icono: Icons.elderly, teclado: TextInputType.number, validator: Validadores.numeroOpcional)),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _fuenteTarifas,
              decoration: const InputDecoration(labelText: 'Fuente de las tarifas preferenciales', filled: true, fillColor: kSuperficie),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Sin tarifas preferenciales')),
                for (final f in _fuentes.entries) DropdownMenuItem<String?>(value: f.key, child: Text(f.value)),
              ],
              onChanged: (v) => setState(() => _fuenteTarifas = v),
            ),
            const TituloSeccion('Cómo reconocer la unidad'),
            CampoTexto(controller: _letrero, etiqueta: 'Letrero (lo que dice el parabrisas)', icono: Icons.text_fields, maximo: 60),
            const SizedBox(height: 10),
            CampoTexto(controller: _descripcion, etiqueta: 'Descripción (ej. blanco con franja verde)', icono: Icons.directions_bus_outlined, maximo: 120),
            const SizedBox(height: 10),
            CampoTexto(controller: _concesionario, etiqueta: 'Concesionario (opcional)', icono: Icons.business_outlined, maximo: 100),
            const SizedBox(height: 10),
            Row(children: [
              if (_foto != null)
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_foto!, width: 90, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: _elegirFoto, icon: const Icon(Icons.photo_camera_outlined), label: Text(_foto == null ? 'Subir foto de la unidad' : 'Cambiar foto')),
            ]),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Ruta activa (visible para el público)'),
              subtitle: const Text('Para activarla necesita un recorrido con trazado, 2 paradas y un horario.'),
              value: _activa,
              activeTrackColor: kAcento,
              onChanged: (v) {
                final faltan = _faltantes();
                if (v && faltan.isNotEmpty) {
                  avisar(context, 'Aún no se puede activar: ${faltan.first}');
                  return;
                }
                setState(() => _activa = v);
              },
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Guardar ruta'),
            ),
            if (_id != null) ..._recorridos(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Lo que impide activar la ruta (mismas reglas que valida la base de datos).
  List<String> _faltantes() {
    if (_id == null) return ['primero guarda los datos de la ruta'];
    final geos = widget.vms.catalogo.cat.geosDeRuta(_id!);
    if (geos.isEmpty) return ['agrega un recorrido (ida, vuelta o circuito)'];
    final listo = geos.any((g) =>
        g.recorrido.trazado.length >= 2 &&
        g.recorrido.paradas.length >= 2 &&
        TipoDia.values.any((td) => widget.vms.catalogo.cat.franjasDe(g.recorrido.id, td).isNotEmpty));
    if (listo) return [];
    return ['algún recorrido necesita trazado, al menos 2 paradas y un horario'];
  }

  /// Checklist para que el admin sepa qué le falta a la ruta.
  Widget _pasos() {
    final cat = widget.vms.catalogo.cat;
    final geos = cat.geosDeRuta(_id ?? -1); // ruta nueva: lista vacía
    final items = <(bool?, String)>[]; // true = hecho, false = falta (bloquea), null = recomendado
    items.add((_id != null, _id == null ? 'Guarda los datos de la ruta (abajo, "Guardar ruta")' : 'Datos de la ruta guardados'));
    items.add((geos.isNotEmpty, geos.isEmpty ? 'Agrega un recorrido (ida, vuelta o circuito)' : '${geos.length} recorrido(s)'));
    for (final g in geos) {
      final nombre = g.recorrido.sentido.etiqueta;
      final pts = g.recorrido.trazado.length;
      final par = g.recorrido.paradas.length;
      items.add((pts >= 2, pts >= 2 ? '$nombre: trazado listo' : '$nombre: falta dibujar el trazado'));
      items.add((par >= 2, par >= 2 ? '$nombre: $par paradas' : '$nombre: faltan paradas (mínimo 2, llevas $par)'));
      final sinHorario = [for (final td in TipoDia.values) if (cat.franjasDe(g.recorrido.id, td).isEmpty) td];
      if (sinHorario.length == TipoDia.values.length) {
        items.add((false, '$nombre: falta el horario'));
      } else if (sinHorario.isNotEmpty) {
        items.add((null, '$nombre: sin horario en ${sinHorario.map((t) => t.etiqueta.toLowerCase()).join(' y ')} (si no hay servicio, está bien)'));
      } else {
        items.add((true, '$nombre: horario completo'));
      }
    }
    final faltan = _faltantes();
    items.add((_activa && faltan.isEmpty ? true : (faltan.isEmpty ? null : false),
        _activa ? 'Ruta activa: la ve el público' : faltan.isEmpty ? 'Lista para activarse (enciende "Ruta activa" y guarda)' : 'Activar la ruta'));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pasos para publicar la ruta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            for (final (hecho, texto) in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    hecho == true ? Icons.check_circle : (hecho == false ? Icons.radio_button_unchecked : Icons.info_outline),
                    size: 18,
                    color: hecho == true ? kVerde : (hecho == false ? kTextoSecundario : kAmbar),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(texto, style: TextStyle(color: hecho == true ? null : kTextoSecundario))),
                ]),
              ),
            if (_id != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('El trazado, las paradas y el horario se editan en "Recorridos", al final.',
                    style: TextStyle(color: kTextoSecundario, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _recorridos() {
    final cat = widget.vms.catalogo.cat;
    final geos = cat.geosDeRuta(_id!);
    final usados = geos.map((g) => g.recorrido.sentido).toSet();
    return [
      const TituloSeccion('Recorridos'),
      if (geos.isEmpty) const Text('Agrega al menos un recorrido (ida, vuelta o circuito).', style: TextStyle(color: kTextoSecundario)),
      for (final g in geos)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.recorrido.sentido.etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${g.linea.puntos.length} puntos · ${(g.linea.largo / 1000).toStringAsFixed(1)} km · ${g.paradas.length} paradas',
                  style: const TextStyle(color: kTextoSecundario)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorRecorridoPage(vms: widget.vms, idRecorrido: g.recorrido.id)));
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit_road),
                  label: const Text('Trazado y paradas'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HorarioPage(vms: widget.vms, idRecorrido: g.recorrido.id)));
                    setState(() {});
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Horario'),
                ),
              ]),
            ]),
          ),
        ),
      Wrap(spacing: 8, children: [
        for (final s in Sentido.values)
          if (!usados.contains(s))
            TextButton.icon(onPressed: () => _agregarRecorrido(s), icon: const Icon(Icons.add), label: Text('Agregar ${s.etiqueta.toLowerCase()}')),
      ]),
    ];
  }
}
