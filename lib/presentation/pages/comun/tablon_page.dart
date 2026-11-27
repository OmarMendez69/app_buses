import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/comunidad.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/reporte_rapido.dart';
import 'nueva_publicacion_page.dart';
import 'publicacion_detalle_page.dart';

/// Tablón comunitario con dos pestañas:
/// - Reportes: retrasos, unidad llena, desvíos… de las últimas 6 horas, agrupados por ruta.
/// - Comunidad: preguntas, objetos perdidos y publicaciones generales.
/// Es informativo: nada de lo que se publica aquí cambia rutas, horarios ni cálculos.
class TablonPage extends StatefulWidget {
  final AppViewModels vms;
  final bool comoPestana;
  const TablonPage({super.key, required this.vms, this.comoPestana = true});

  @override
  State<TablonPage> createState() => _TablonPageState();
}

class _TablonPageState extends State<TablonPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  CategoriaPublicacion? _categoria; // filtro de la pestaña Comunidad
  bool _misRutas = false;
  late Future<List<Publicacion>> _reportes;
  late Future<List<Publicacion>> _comunidad;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
    _reportes = _consultaReportes();
    _comunidad = _consultaComunidad();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Set<int>? get _rutas => _misRutas ? widget.vms.favoritos.ids : null;

  Future<List<Publicacion>> _consultaReportes() => widget.vms.comunidad.publicaciones(
        categorias: CategoriaPublicacion.reportes,
        desde: DateTime.now().subtract(const Duration(hours: 6)),
        rutas: _rutas,
        limite: 100,
      );

  Future<List<Publicacion>> _consultaComunidad() => widget.vms.comunidad.publicaciones(
        categorias: _categoria != null ? {_categoria!} : CategoriaPublicacion.comunidad,
        rutas: _rutas,
      );

  void _cargar() {
    if (!mounted) return;
    setState(() {
      _reportes = _consultaReportes();
      _comunidad = _consultaComunidad();
    });
  }

  Future<void> _accion() async {
    if (_tabs.index == 0) {
      if (await mostrarReporteRapido(context, widget.vms)) _cargar();
      return;
    }
    if (!widget.vms.sesion.puedePublicar) {
      avisar(context, tx('Tu cuenta está suspendida.', 'Your account is suspended.'));
      return;
    }
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => NuevaPublicacionPage(vms: widget.vms, soloComunidad: true)));
    if (ok == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final puede = widget.vms.sesion.conSesion;
    final enReportes = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.comoPestana,
        title: Row(children: [
          Text(tx('Tablón', 'Board')),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: kTextoSecundario), borderRadius: BorderRadius.circular(8)),
            child: Text(tx('Comunitario', 'Community'), style: const TextStyle(fontSize: 11, color: kTextoSecundario)),
          ),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kAcento,
          tabs: [
            Tab(icon: const Icon(Icons.campaign_outlined), text: tx('Reportes', 'Reports')),
            Tab(icon: const Icon(Icons.forum_outlined), text: tx('Comunidad', 'Community')),
          ],
        ),
      ),
      floatingActionButton: puede
          ? FloatingActionButton.extended(
              heroTag: 'publicar',
              backgroundColor: kAcento,
              onPressed: _accion,
              icon: Icon(enReportes ? Icons.campaign_outlined : Icons.edit),
              label: Text(enReportes ? tx('Reportar', 'Report') : tx('Publicar', 'Post')),
            )
          : null,
      body: Column(
        children: [
          if (!puede)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(tx('Estás como visitante: puedes leer. Para reportar, publicar o comentar crea una cuenta.',
                  'You are a visitor: you can read. Create an account to report, post or comment.'),
                  style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_pestanaReportes(), _pestanaComunidad()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipMisRutas() => FilterChip(
        label: Text(tx('Mis rutas', 'My routes')),
        selected: _misRutas,
        onSelected: (v) {
          _misRutas = v;
          _cargar();
        },
      );

  Widget _pestanaReportes() {
    final cat = widget.vms.catalogo.cat;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            _chipMisRutas(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tx('Últimas 6 horas · no verificados', 'Last 6 hours · unverified'),
                  style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Publicacion>>(
            future: _reportes,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Cargando();
              if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!), icono: Icons.cloud_off);
              final lista = snap.data!;
              if (lista.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _cargar(),
                  child: ListView(children: [
                    const SizedBox(height: 80),
                    EstadoVacio(
                      mensaje: tx('Sin reportes en las últimas 6 horas', 'No reports in the last 6 hours'),
                      icono: Icons.check_circle_outline,
                    ),
                  ]),
                );
              }
              // Agrupar por ruta, conservando el orden del reporte más reciente de cada una.
              final grupos = <int?, List<Publicacion>>{};
              for (final p in lista) {
                grupos.putIfAbsent(p.idRuta, () => []).add(p);
              }
              return RefreshIndicator(
                onRefresh: () async => _cargar(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  children: [
                    for (final g in grupos.entries) ...[
                      _encabezadoRuta(cat.rutaPorId[g.key]?.nombre, cat.rutaPorId[g.key]?.color, g.value.length),
                      for (final p in g.value) TarjetaPublicacion(vms: widget.vms, p: p, alVolver: _cargar),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _encabezadoRuta(String? nombre, String? color, int n) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Row(children: [
          Icon(Icons.circle, size: 12, color: color == null ? kTextoSecundario : colorDesdeHex(color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(nombre ?? tx('Sin ruta', 'No route'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Text(n == 1 ? tx('1 reporte', '1 report') : tx('$n reportes', '$n reports'),
              style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
        ]),
      );

  Widget _pestanaComunidad() {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _chipMisRutas(),
              const SizedBox(width: 6),
              for (final c in CategoriaPublicacion.comunidad) ...[
                ChoiceChip(
                  label: Text(c.etiqueta),
                  selected: _categoria == c,
                  onSelected: (v) {
                    _categoria = v ? c : null;
                    _cargar();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Publicacion>>(
            future: _comunidad,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Cargando();
              if (snap.hasError) return EstadoVacio(mensaje: mensajeError(snap.error!), icono: Icons.cloud_off);
              final lista = snap.data!;
              if (lista.isEmpty) return EstadoVacio(mensaje: tx('Aún no hay publicaciones', 'No posts yet'), icono: Icons.forum_outlined);
              return RefreshIndicator(
                onRefresh: () async => _cargar(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: lista.length,
                  itemBuilder: (context, i) => TarjetaPublicacion(vms: widget.vms, p: lista[i], alVolver: _cargar),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TarjetaPublicacion extends StatelessWidget {
  final AppViewModels vms;
  final Publicacion p;
  final VoidCallback alVolver;
  const TarjetaPublicacion({super.key, required this.vms, required this.p, required this.alVolver});

  @override
  Widget build(BuildContext context) {
    final cat = vms.catalogo.cat;
    final ruta = p.idRuta == null ? null : cat.rutaPorId[p.idRuta];
    final parada = p.idParada == null ? null : cat.paradaPorId[p.idParada];
    return Opacity(
      opacity: p.reciente ? 1 : 0.55,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicacionDetallePage(vms: vms, idPublicacion: p.id)));
            alVolver();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(p.categoria.icono, size: 18, color: kAmbar),
                  const SizedBox(width: 6),
                  Text(p.categoria.etiqueta, style: const TextStyle(color: kAmbar, fontWeight: FontWeight.w600)),
                  if (ruta != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: colorDesdeHex(ruta.color), borderRadius: BorderRadius.circular(6)),
                      child: Text(ruta.nombre, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                  const Spacer(),
                  Text(haceCuanto(p.creadoEn), style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                Text(p.texto),
                if (parada != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('📍 ${parada.nombre}', style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  Text(p.autor, style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                  const Spacer(),
                  Icon(p.marcadaUtil ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16, color: kTextoSecundario),
                  Text(' ${p.utiles}   ', style: const TextStyle(color: kTextoSecundario)),
                  const Icon(Icons.chat_bubble_outline, size: 16, color: kTextoSecundario),
                  Text(' ${p.comentarios}', style: const TextStyle(color: kTextoSecundario)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
