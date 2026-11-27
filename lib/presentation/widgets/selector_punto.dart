import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_colors.dart';
import '../../core/idioma.dart';
import '../../domain/entities/viaje.dart';
import '../viewmodels/app_view_models.dart';
import 'comunes.dart';
import 'mapa.dart';

/// Abre el buscador y devuelve el punto elegido (o null).
Future<PuntoNombrado?> elegirPunto(BuildContext context, AppViewModels vms, {required String titulo, bool permitirUbicacion = true}) {
  return Navigator.of(context).push<PuntoNombrado>(
    MaterialPageRoute(builder: (_) => SelectorPuntoPage(vms: vms, titulo: titulo, permitirUbicacion: permitirUbicacion)),
  );
}

/// Buscador: primero lugares de interés y paradas (sin internet);
/// si no hay coincidencia, busca la dirección con Nominatim.
class SelectorPuntoPage extends StatefulWidget {
  final AppViewModels vms;
  final String titulo;
  final bool permitirUbicacion;
  const SelectorPuntoPage({super.key, required this.vms, required this.titulo, this.permitirUbicacion = true});

  @override
  State<SelectorPuntoPage> createState() => _SelectorPuntoPageState();
}

class _SelectorPuntoPageState extends State<SelectorPuntoPage> {
  final _texto = TextEditingController();
  List<PuntoNombrado> _direcciones = [];
  bool _buscando = false;
  bool _ubicando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _buscarDireccion() async {
    setState(() => _buscando = true);
    final r = await widget.vms.externos.geocodificar(_texto.text);
    if (!mounted) return;
    setState(() {
      _direcciones = r;
      _buscando = false;
    });
    if (r.isEmpty) avisarLocal(tx('No encontré esa dirección en Dolores.', "Couldn't find that address in Dolores."));
  }

  void avisarLocal(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _miUbicacion() async {
    setState(() => _ubicando = true);
    final u = await widget.vms.catalogo.actualizarUbicacion();
    if (!mounted) return;
    setState(() => _ubicando = false);
    if (u == null) {
      avisarLocal(tx('No pude obtener tu ubicación.', "Couldn't get your location."));
      return;
    }
    Navigator.pop(context, PuntoNombrado(tx('Mi ubicación', 'My location'), u));
  }

  Future<void> _enMapa() async {
    final p = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => ElegirEnMapaPage(vms: widget.vms, titulo: widget.titulo)),
    );
    if (p != null && mounted) Navigator.pop(context, PuntoNombrado(tx('Punto en el mapa', 'Point on map'), p));
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    final q = quitarAcentos(_texto.text.trim());
    final lugares = q.isEmpty
        ? cat.lugaresActivos.take(12).toList()
        : cat.lugaresActivos.where((l) => quitarAcentos(l.nombre).contains(q)).toList();
    final paradas = q.length < 2 ? const [] : cat.paradasActivas.where((p) => quitarAcentos(p.nombre).contains(q) || quitarAcentos(p.referencia ?? '').contains(q)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _texto,
              autofocus: true,
              onChanged: (_) => setState(() => _direcciones = []),
              onSubmitted: (_) => _buscarDireccion(),
              decoration: InputDecoration(
                hintText: tx('Lugar, parada o dirección', 'Place, stop or address'),
                prefixIcon: const Icon(Icons.search, color: kAcento),
                filled: true,
                fillColor: kSuperficie,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (widget.permitirUbicacion)
                  ListTile(
                    leading: _ubicando
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, color: Colors.blueAccent),
                    title: Text(tx('Usar mi ubicación', 'Use my location')),
                    onTap: _ubicando ? null : _miUbicacion,
                  ),
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: kAcento),
                  title: Text(tx('Elegir en el mapa', 'Pick on the map')),
                  onTap: _enMapa,
                ),
                if (lugares.isNotEmpty) TituloSeccionPad(tx('Lugares', 'Places')),
                for (final l in lugares)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(l.nombre),
                    subtitle: Text(l.categoria.etiqueta),
                    onTap: () => Navigator.pop(context, PuntoNombrado(l.nombre, l.punto)),
                  ),
                if (paradas.isNotEmpty) TituloSeccionPad(tx('Paradas', 'Stops')),
                for (final p in paradas)
                  ListTile(
                    leading: const Icon(Icons.signpost_outlined),
                    title: Text(p.nombre),
                    subtitle: p.referencia == null ? null : Text(p.referencia!),
                    onTap: () => Navigator.pop(context, PuntoNombrado(p.nombre, p.punto)),
                  ),
                if (q.length >= 3) ...[
                  TituloSeccionPad(tx('Direcciones', 'Addresses')),
                  if (_buscando)
                    const Padding(padding: EdgeInsets.all(16), child: Cargando())
                  else if (_direcciones.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.travel_explore, color: kAcento),
                      title: Text(tx('Buscar "${_texto.text.trim()}" en Dolores', 'Search "${_texto.text.trim()}" in Dolores')),
                      subtitle: Text(tx('Necesita internet', 'Needs internet')),
                      onTap: _buscarDireccion,
                    ),
                  for (final d in _direcciones)
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: Text(d.nombre),
                      onTap: () => Navigator.pop(context, d),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TituloSeccionPad extends StatelessWidget {
  final String texto;
  const TituloSeccionPad(this.texto, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TituloSeccion(texto));
}

/// Toca el mapa para elegir un punto. Devuelve LatLng.
class ElegirEnMapaPage extends StatefulWidget {
  final AppViewModels vms;
  final String titulo;
  final LatLng? inicial;
  const ElegirEnMapaPage({super.key, required this.vms, required this.titulo, this.inicial});

  @override
  State<ElegirEnMapaPage> createState() => _ElegirEnMapaPageState();
}

class _ElegirEnMapaPageState extends State<ElegirEnMapaPage> {
  LatLng? _punto;

  @override
  void initState() {
    super.initState();
    _punto = widget.inicial;
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.vms.catalogo.cat;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Stack(
        children: [
          MapaBase(
            centro: widget.inicial ?? widget.vms.catalogo.ubicacion,
            zoom: 15,
            alTocar: (p) => setState(() => _punto = p),
            capas: [
              capaRecorridos(cat.geosActivos, grosor: 3),
              if (_punto != null) MarkerLayer(markers: [marcadorIcono(_punto!, Icons.location_on, kAcento)]),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: FilledButton.icon(
              onPressed: _punto == null ? null : () => Navigator.pop(context, _punto),
              icon: const Icon(Icons.check),
              label: Text(_punto == null ? tx('Toca el mapa', 'Tap the map') : tx('Usar este punto', 'Use this point')),
              style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(16)),
            ),
          ),
        ],
      ),
    );
  }
}
