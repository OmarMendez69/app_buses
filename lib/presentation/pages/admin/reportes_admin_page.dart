import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/comunidad.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../comun/publicacion_detalle_page.dart';
import 'avisos_admin_page.dart';

/// Reportes de la comunidad (retraso, unidad llena, desvío, no pasó, incidente)
/// agrupados por ruta. El admin los revisa, oculta los falsos y, si confirma
/// el problema, los convierte en un aviso oficial (que sí notifica).
class ReportesAdminPage extends StatefulWidget {
  final AppViewModels vms;
  const ReportesAdminPage({super.key, required this.vms});

  @override
  State<ReportesAdminPage> createState() => _ReportesAdminPageState();
}

class _ReportesAdminPageState extends State<ReportesAdminPage> {
  int _horas = 24;
  late Future<List<Publicacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _consulta();
  }

  Future<List<Publicacion>> _consulta() => widget.vms.comunidad.publicaciones(
        categorias: CategoriaPublicacion.reportes,
        desde: DateTime.now().subtract(Duration(hours: _horas)),
        limite: 500,
      );

  void _cargar() {
    if (!mounted) return;
    setState(() => _futuro = _consulta());
  }

  Future<void> _ocultar(Publicacion p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Ocultar este reporte?'),
        content: Text('"${p.texto}"\n\nDejará de verse en el tablón y en el detalle de la ruta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ocultar', style: TextStyle(color: kAcento))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.vms.admin.ocultarPublicacion(p.id);
      if (mounted) avisar(context, 'Reporte ocultado');
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _crearAviso(_Grupo g) async {
    final ruta = widget.vms.catalogo.cat.rutaPorId[g.idRuta];
    if (ruta == null) return;
    final principal = g.categoriaPrincipal;
    final (tipo, titulo) = switch (principal) {
      CategoriaPublicacion.desvio => (TipoAviso.desvio, 'Desvío en la ruta ${ruta.nombre}'),
      CategoriaPublicacion.noPaso => (TipoAviso.general, 'La ruta ${ruta.nombre} no está pasando con normalidad'),
      CategoriaPublicacion.retraso => (TipoAviso.general, 'Retrasos en la ruta ${ruta.nombre}'),
      CategoriaPublicacion.unidadLlena => (TipoAviso.general, 'Unidades llenas en la ruta ${ruta.nombre}'),
      _ => (TipoAviso.general, 'Incidente en la ruta ${ruta.nombre}'),
    };
    final paradas = g.paradas.keys.toSet();
    final nombresParadas = paradas.map((id) => widget.vms.catalogo.cat.paradaPorId[id]?.nombre).whereType<String>().toList();
    final detalle = StringBuffer('Confirmamos lo que reportaron los usuarios: ${principal.etiqueta.toLowerCase()}');
    if (nombresParadas.isNotEmpty) detalle.write(' a la altura de ${nombresParadas.join(', ')}');
    detalle.write('. Te avisaremos cuando se normalice.');

    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => AvisoFormPage(
        vms: widget.vms,
        idRutaInicial: ruta.id,
        tipoInicial: tipo,
        tituloInicial: titulo.length > 80 ? titulo.substring(0, 80) : titulo,
        detalleInicial: detalle.toString(),
        paradasIniciales: paradas,
      ),
    ));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de la comunidad'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 24, label: Text('Últimas 24 h')),
                ButtonSegment(value: 24 * 7, label: Text('Últimos 7 días')),
              ],
              selected: {_horas},
              onSelectionChanged: (s) {
                _horas = s.first;
                _cargar();
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No están verificados. Si confirmas un problema, publícalo como aviso oficial: '
              'eso sí llega como notificación a quienes siguen la ruta.',
              style: TextStyle(color: kTextoSecundario, fontSize: 12),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Publicacion>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Cargando();
                if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!), icono: Icons.cloud_off);
                final grupos = _agrupar(snap.data!);
                if (grupos.isEmpty) {
                  return EstadoVacio(
                    mensaje: _horas == 24 ? 'Sin reportes en las últimas 24 horas' : 'Sin reportes en los últimos 7 días',
                    icono: Icons.check_circle_outline,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _cargar(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [for (final g in grupos) _tarjeta(g)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_Grupo> _agrupar(List<Publicacion> lista) {
    final porRuta = <int?, _Grupo>{};
    for (final p in lista) {
      porRuta.putIfAbsent(p.idRuta, () => _Grupo(p.idRuta)).agregar(p);
    }
    // Primero las rutas con más personas distintas reportando, luego las más recientes.
    return porRuta.values.toList()
      ..sort((a, b) {
        final c = b.personas.compareTo(a.personas);
        return c != 0 ? c : b.ultimo.compareTo(a.ultimo);
      });
  }

  Widget _tarjeta(_Grupo g) {
    final cat = widget.vms.catalogo.cat;
    final ruta = g.idRuta == null ? null : cat.rutaPorId[g.idRuta];
    final varios = g.personas >= 3;
    return Card(
      shape: varios
          ? RoundedRectangleBorder(side: const BorderSide(color: kAmbar), borderRadius: BorderRadius.circular(16))
          : null,
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(Icons.circle, color: ruta == null ? kTextoSecundario : colorDesdeHex(ruta.color)),
        title: Text(ruta?.nombre ?? 'Sin ruta', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${g.reportes.length} reporte(s) de ${g.personas} persona(s) · último ${haceCuanto(g.ultimo)}',
              style: TextStyle(color: varios ? kAmbar : kTextoSecundario, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in g.porCategoria.entries)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(e.key.icono, size: 16),
                  label: Text('${e.key.etiqueta} · ${e.value}', style: const TextStyle(fontSize: 12)),
                ),
            ]),
          ],
        ),
        children: [
          for (final p in g.reportes)
            ListTile(
              dense: true,
              leading: Icon(p.categoria.icono, color: kAmbar),
              title: Text(p.texto),
              subtitle: Text([
                if (p.idParada != null && cat.paradaPorId[p.idParada] != null) '📍 ${cat.paradaPorId[p.idParada]!.nombre}',
                '${p.autor} · ${haceCuanto(p.creadoEn)}',
              ].join('\n')),
              onTap: () => abrir(context, PublicacionDetallePage(vms: widget.vms, idPublicacion: p.id)),
              trailing: IconButton(
                icon: const Icon(Icons.visibility_off_outlined),
                tooltip: 'Ocultar (falso o spam)',
                onPressed: () => _ocultar(p),
              ),
            ),
          if (ruta != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kAcento),
                onPressed: () => _crearAviso(g),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Publicar aviso oficial'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reportes de una ruta con sus cuentas.
class _Grupo {
  final int? idRuta;
  final List<Publicacion> reportes = [];
  final Set<String> _usuarios = {};
  final Map<CategoriaPublicacion, int> porCategoria = {};
  final Map<int, int> paradas = {};
  DateTime ultimo = DateTime.fromMillisecondsSinceEpoch(0);

  _Grupo(this.idRuta);

  void agregar(Publicacion p) {
    reportes.add(p);
    if (p.idUsuario != null) _usuarios.add(p.idUsuario!);
    porCategoria[p.categoria] = (porCategoria[p.categoria] ?? 0) + 1;
    if (p.idParada != null) paradas[p.idParada!] = (paradas[p.idParada!] ?? 0) + 1;
    if (p.creadoEn.isAfter(ultimo)) ultimo = p.creadoEn;
  }

  /// Personas distintas (las cuentas eliminadas cuentan como una sola).
  int get personas => _usuarios.length + (reportes.any((p) => p.idUsuario == null) ? 1 : 0);

  CategoriaPublicacion get categoriaPrincipal =>
      (porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}
