import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../domain/catalogo.dart';
import '../../../domain/entities/comunidad.dart';
import '../../../domain/entities/transporte.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa.dart';
import '../../widgets/reporte_rapido.dart';
import 'hora_pico_page.dart';
import 'parada_detalle_page.dart';
import 'publicacion_detalle_page.dart';

class RutaDetallePage extends StatefulWidget {
  final AppViewModels vms;
  final int idRuta;
  const RutaDetallePage({super.key, required this.vms, required this.idRuta});

  @override
  State<RutaDetallePage> createState() => _RutaDetallePageState();
}

class _RutaDetallePageState extends State<RutaDetallePage> {
  int _sentido = 0;
  late Future<List<Publicacion>> _publicaciones;

  @override
  void initState() {
    super.initState();
    _publicaciones = _consultaReportes();
  }

  Future<List<Publicacion>> _consultaReportes() => widget.vms.comunidad
      .publicaciones(
        idRuta: widget.idRuta,
        categorias: CategoriaPublicacion.reportes,
        desde: DateTime.now().subtract(const Duration(hours: 6)),
        limite: 10,
      )
      .catchError((_) => <Publicacion>[]);

  Future<void> _reportar() async {
    if (await mostrarReporteRapido(context, widget.vms, idRuta: widget.idRuta) && mounted) {
      setState(() => _publicaciones = _consultaReportes());
    }
  }

  @override
  Widget build(BuildContext context) {
    final vms = widget.vms;
    return ListenableBuilder(
      listenable: Listenable.merge([vms.catalogo, vms.favoritos]),
      builder: (context, _) {
        final cat = vms.catalogo.cat;
        final ruta = cat.rutaPorId[widget.idRuta];
        if (ruta == null) {
          return Scaffold(appBar: AppBar(), body: EstadoVacio(mensaje: tx('Esta ruta ya no está disponible', 'This route is no longer available')));
        }
        final geos = cat.geosDeRuta(ruta.id);
        final geo = geos.isEmpty ? null : geos[_sentido.clamp(0, geos.length - 1)];
        final ahora = DateTime.now();
        final estado = cat.estadoRuta(ruta.id, ahora);
        final avisos = cat.avisosVigentes(ahora, idRuta: ruta.id, incluirGenerales: false);
        final color = colorDesdeHex(ruta.color);

        return Scaffold(
          appBar: AppBar(
            title: Text(ruta.nombre),
            actions: [
              IconButton(
                icon: Icon(vms.favoritos.sigue(ruta.id) ? Icons.star : Icons.star_border, color: kAmbar),
                tooltip: tx('Seguir ruta', 'Follow route'),
                onPressed: () async {
                  final seguia = vms.favoritos.sigue(ruta.id);
                  await vms.favoritos.alternar(ruta.id);
                  if (context.mounted) {
                    avisar(context, seguia
                        ? tx('Dejaste de seguir esta ruta', 'You unfollowed this route')
                        : tx('Recibirás los avisos de esta ruta', "You'll get this route's notices"));
                  }
                },
              ),
            ],
          ),
          body: ListView(
            children: [
              SizedBox(
                height: 260,
                child: MapaBase(
                  centro: geo != null && geo.usable ? geo.linea.puntoEn(geo.linea.largo / 2) : null,
                  zoom: 14,
                  capas: [
                    if (geo != null) capaRecorridos([geo], grosor: 6),
                    if (geo != null)
                      MarkerLayer(markers: [
                        for (final p in geo.paradas)
                          marcadorParada(p.$1, tam: 14, alTocar: () => abrir(context, ParadaDetallePage(vms: vms, idParada: p.$1.id))),
                      ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (geos.length > 1)
                      SegmentedButton<int>(
                        segments: [
                          for (var i = 0; i < geos.length; i++)
                            ButtonSegment(value: i, label: Text(geos[i].recorrido.sentido.etiqueta)),
                        ],
                        selected: {_sentido.clamp(0, geos.length - 1)},
                        onSelectionChanged: (s) => setState(() => _sentido = s.first),
                      ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.circle, size: 12, color: colorEstado(estado)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(textoEstado(estado), style: TextStyle(color: colorEstado(estado), fontWeight: FontWeight.w600))),
                    ]),
                    if (estado.ultimoServicio != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(tx('Último servicio de hoy: ${textoHora(estado.ultimoServicio!)}', "Today's last service: ${textoHora(estado.ultimoServicio!)}"),
                            style: const TextStyle(color: kTextoSecundario)),
                      ),
                    const SizedBox(height: 10),
                    _botonAvisos(ruta.id),
                    for (final a in avisos) TarjetaAviso(aviso: a, ruta: ruta),
                    _reconocer(ruta, color),
                    _tarifas(ruta),
                    if (geo != null) ..._paradas(context, geo),
                    if (geo != null) ..._horario(cat, geo),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => abrir(context, HoraPicoPage(vms: vms, idRuta: ruta.id)),
                      icon: const Icon(Icons.schedule),
                      label: Text(tx('Hora pico (horarios de alta demanda)', 'Peak hours (high demand times)')),
                    ),
                    TituloSeccion(tx('Reportes de la comunidad (últimas 6 h)', 'Community reports (last 6 h)')),
                    Text(tx('No verificados: los envían otros usuarios.', 'Unverified: sent by other users.'),
                        style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                    FutureBuilder<List<Publicacion>>(
                      future: _publicaciones,
                      builder: (context, snap) {
                        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(12), child: Cargando());
                        final lista = snap.data!;
                        if (lista.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(tx('Sin reportes recientes de esta ruta.', 'No recent reports for this route.'),
                                style: const TextStyle(color: kTextoSecundario)),
                          );
                        }
                        return Column(children: [
                          for (final p in lista)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(p.categoria.icono, color: kTextoSecundario),
                              title: Text(p.texto, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${p.categoria.etiqueta} · ${p.autor} · ${haceCuanto(p.creadoEn)}'),
                              onTap: () => abrir(context, PublicacionDetallePage(vms: vms, idPublicacion: p.id)),
                            ),
                        ]);
                      },
                    ),
                    if (vms.sesion.conSesion)
                      OutlinedButton.icon(
                        onPressed: _reportar,
                        icon: const Icon(Icons.campaign_outlined),
                        label: Text(tx('Reportar algo de esta ruta', 'Report something on this route')),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      tx('Datos revisados el ${ruta.revisadaEn.day}/${ruta.revisadaEn.month}/${ruta.revisadaEn.year}',
                          'Data reviewed on ${ruta.revisadaEn.day}/${ruta.revisadaEn.month}/${ruta.revisadaEn.year}'),
                      style: const TextStyle(color: kTextoSecundario, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Seguir la ruta = recibir sus avisos. Antes solo era una estrella en la barra
  /// superior y no se entendía que de eso dependían las notificaciones.
  Widget _botonAvisos(int idRuta) {
    final vms = widget.vms;
    final sigue = vms.favoritos.sigue(idRuta);
    Future<void> alternar() async {
      await vms.favoritos.alternar(idRuta);
      if (mounted) {
        avisar(context, sigue
            ? tx('Ya no recibirás avisos de esta ruta', "You won't get notices for this route anymore")
            : tx('Listo: te avisaremos si esta ruta cambia', "Done: we'll notify you if this route changes"));
      }
    }

    if (sigue) {
      return OutlinedButton.icon(
        onPressed: alternar,
        icon: const Icon(Icons.notifications_active, color: kAmbar),
        label: Text(tx('Recibes avisos de esta ruta · dejar de seguir', 'You get notices for this route · unfollow')),
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: kAcento, padding: const EdgeInsets.all(14)),
      onPressed: alternar,
      icon: const Icon(Icons.notifications_outlined),
      label: Text(tx('Avisarme si esta ruta cambia', 'Notify me if this route changes')),
    );
  }

  Widget _reconocer(Ruta r, Color color) {
    if (r.fotoUnidad == null && r.letrero == null && r.descripcionUnidad == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(tx('Cómo reconocerlo', 'How to spot it')),
        if (r.fotoUnidad != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              r.fotoUnidad!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (r.letrero != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black, border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(6)),
            child: Text(r.letrero!, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        if (r.descripcionUnidad != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.descripcionUnidad!)),
      ],
    );
  }

  Widget _tarifas(Ruta r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(tx('Tarifa', 'Fare')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('${tx('General', 'Regular')} \$${r.tarifa.toStringAsFixed(2)}')),
          if (r.tarifaEstudiante != null) Chip(label: Text('${tx('Estudiante', 'Student')} \$${r.tarifaEstudiante!.toStringAsFixed(2)}')),
          if (r.tarifaInapam != null) Chip(label: Text('INAPAM \$${r.tarifaInapam!.toStringAsFixed(2)}')),
        ]),
        if (r.fuenteTarifas != null)
          Text(tx('Fuente: ${etiquetaFuente(r.fuenteTarifas!)}', 'Source: ${etiquetaFuente(r.fuenteTarifas!)}'),
              style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
      ],
    );
  }

  List<Widget> _paradas(BuildContext context, RecorridoGeo geo) {
    final paradas = [...geo.paradas]..sort((a, b) => a.$2.compareTo(b.$2));
    return [
      TituloSeccion(tx('Paradas (${paradas.length})', 'Stops (${paradas.length})')),
      Text(tx('El camión también se para donde le hagas la mano sobre el recorrido.', 'The bus also stops anywhere along the route if you wave it down.'),
          style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
      for (var i = 0; i < paradas.length; i++)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 14, backgroundColor: colorDesdeHex(geo.ruta.color), child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))),
          title: Text(paradas[i].$1.nombre),
          subtitle: paradas[i].$1.referencia == null ? null : Text(paradas[i].$1.referencia!),
          trailing: paradas[i].$3 == null ? null : Text('+${paradas[i].$3} min', style: const TextStyle(color: kTextoSecundario)),
          onTap: () => abrir(context, ParadaDetallePage(vms: widget.vms, idParada: paradas[i].$1.id)),
        ),
    ];
  }

  List<Widget> _horario(Catalogo cat, RecorridoGeo geo) {
    final hoy = cat.tipoDia(DateTime.now());
    final especial = cat.diaEspecial(DateTime.now());
    return [
      TituloSeccion(tx('Horario', 'Schedule')),
      if (especial != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(tx('Hoy es ${especial.nombre}: aplica el horario de ${especial.tipoDia.etiqueta.toLowerCase()}.',
              'Today is ${especial.nombre}: ${especial.tipoDia.etiqueta} schedule applies.'), style: const TextStyle(color: kAmbar)),
        ),
      for (final td in TipoDia.values) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(td.etiqueta + (td == hoy ? tx(' (hoy)', ' (today)') : ''),
              style: TextStyle(fontWeight: FontWeight.w600, color: td == hoy ? kAcento : null)),
        ),
        ...() {
          final franjas = cat.franjasDe(geo.recorrido.id, td);
          if (franjas.isEmpty) return [Text(tx('Sin servicio', 'No service'), style: const TextStyle(color: kTextoSecundario))];
          return [
            for (final f in franjas)
              Text('${textoHora(f.inicio)} – ${textoHora(f.fin)} · ${tx('cada', 'every')} ${rangoMinutos(f.frecuenciaMin, f.frecuenciaMax)}'),
          ];
        }(),
      ],
    ];
  }
}
