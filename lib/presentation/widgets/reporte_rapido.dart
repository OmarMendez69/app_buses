import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/idioma.dart';
import '../../data/repositorios/comunidad_repository.dart';
import '../../domain/entities/comunidad.dart';
import '../navigation/navegacion.dart';
import '../viewmodels/app_view_models.dart';

/// Abre la hoja de "Reportar" (retraso, unidad llena, desvío, no pasó, incidente).
/// Con [idRuta] la ruta queda fija (detalle de ruta). Con [idRutaSugerida] viene
/// preseleccionada pero se puede cambiar (botón del inicio, ruta más cercana).
/// Devuelve true si se envió el reporte.
Future<bool> mostrarReporteRapido(BuildContext context, AppViewModels vms, {int? idRuta, int? idRutaSugerida}) async {
  if (!vms.sesion.conSesion) {
    avisar(context, tx('Crea una cuenta para reportar.', 'Create an account to report.'));
    return false;
  }
  if (!vms.sesion.puedePublicar) {
    avisar(context, tx('Tu cuenta está suspendida.', 'Your account is suspended.'));
    return false;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: kSuperficie,
    builder: (_) => _HojaReporte(vms: vms, idRuta: idRuta, idRutaSugerida: idRutaSugerida),
  );
  if (ok == true && context.mounted) {
    avisar(context, tx('Reporte enviado. ¡Gracias!', 'Report sent. Thanks!'));
  }
  return ok == true;
}

class _HojaReporte extends StatefulWidget {
  final AppViewModels vms;
  final int? idRuta;
  final int? idRutaSugerida;
  const _HojaReporte({required this.vms, this.idRuta, this.idRutaSugerida});

  @override
  State<_HojaReporte> createState() => _HojaReporteState();
}

class _HojaReporteState extends State<_HojaReporte> {
  final _nota = TextEditingController();
  int? _ruta;
  int? _parada;
  CategoriaPublicacion? _categoria;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cat = widget.vms.catalogo.cat;
    final inicial = widget.idRuta ?? widget.idRutaSugerida;
    // Solo se preselecciona si la ruta sigue activa (si no, el menú no la tendría).
    _ruta = cat.rutasActivas.any((r) => r.id == inicial) ? inicial : null;
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final cat = _categoria;
    if (cat == null || _ruta == null) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final nota = _nota.text.trim();
      await widget.vms.comunidad.publicar(
        cat,
        nota.length >= 3 ? nota : cat.textoPorDefecto,
        idRuta: _ruta,
        idParada: _parada,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final rutas = cat.rutasActivas;
    final ruta = _ruta == null ? null : cat.rutaPorId[_ruta];

    // Paradas de la ruta elegida (ambos sentidos, sin repetir), en orden de recorrido.
    final paradas = <int, String>{};
    if (_ruta != null) {
      for (final g in cat.geosDeRuta(_ruta!)) {
        final orden = [...g.paradas]..sort((a, b) => a.$2.compareTo(b.$2));
        for (final p in orden) {
          paradas.putIfAbsent(p.$1.id, () => p.$1.nombre);
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tx('Reportar', 'Report'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (widget.idRuta == null || ruta == null)
                DropdownButtonFormField<int>(
                  initialValue: _ruta,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tx('Ruta', 'Route'), filled: true, fillColor: kFondo),
                  items: [for (final r in rutas) DropdownMenuItem(value: r.id, child: Text(r.nombre))],
                  onChanged: (v) => setState(() {
                    _ruta = v;
                    _parada = null;
                  }),
                )
              else if (ruta != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: colorDesdeHex(ruta.color), borderRadius: BorderRadius.circular(8)),
                    child: Text(ruta.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(height: 14),
              Text(tx('¿Qué está pasando?', "What's happening?"), style: const TextStyle(color: kTextoSecundario)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in CategoriaPublicacion.reportes)
                    ChoiceChip(
                      avatar: Icon(c.icono, size: 18),
                      label: Text(c.etiqueta),
                      selected: _categoria == c,
                      onSelected: (_) => setState(() => _categoria = c),
                    ),
                ],
              ),
              if (paradas.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  key: ValueKey(_ruta),
                  initialValue: _parada,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tx('¿Dónde? (opcional)', 'Where? (optional)'), filled: true, fillColor: kFondo),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(tx('Sin parada', 'No stop'))),
                    for (final e in paradas.entries)
                      DropdownMenuItem<int?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _parada = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _nota,
                maxLength: 200,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tx('Nota (opcional)', 'Note (optional)'),
                  hintText: _categoria?.textoPorDefecto,
                  filled: true,
                  fillColor: kFondo,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
                onPressed: (_enviando || _categoria == null || _ruta == null) ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(tx('Enviar reporte', 'Send report')),
              ),
              const SizedBox(height: 10),
              Text(
                tx('Es un reporte comunitario: lo ven todos durante 6 horas, pero no cambia rutas ni horarios.',
                    'This is a community report: everyone sees it for 6 hours, but it does not change routes or schedules.'),
                style: const TextStyle(color: kTextoSecundario, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
