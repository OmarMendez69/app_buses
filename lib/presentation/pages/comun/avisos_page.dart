import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../domain/entities/transporte.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

/// Avisos vigentes y recientes. Filtro: todos o solo mis rutas.
class AvisosPage extends StatefulWidget {
  final AppViewModels vms;
  const AvisosPage({super.key, required this.vms});

  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

class _AvisosPageState extends State<AvisosPage> {
  bool _soloMias = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx('Avisos', 'Notices'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.vms.catalogo, widget.vms.favoritos]),
        builder: (context, _) {
          final cat = widget.vms.catalogo.cat;
          final favs = widget.vms.favoritos.ids;
          final ahora = DateTime.now();
          final lista = [...cat.avisos]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
          final filtrados = _soloMias ? lista.where((a) => a.idRuta == null || favs.contains(a.idRuta)).toList() : lista;
          final vigentes = filtrados.where((a) => a.vigenteEn(ahora)).toList();
          final pasados = filtrados.where((a) => !a.vigenteEn(ahora)).toList();

          return RefreshIndicator(
            onRefresh: widget.vms.catalogo.refrescar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(tx('Todos', 'All'))),
                    ButtonSegment(value: true, label: Text(tx('Mis rutas', 'My routes'))),
                  ],
                  selected: {_soloMias},
                  onSelectionChanged: (s) => setState(() => _soloMias = s.first),
                ),
                TituloSeccion(tx('Vigentes', 'Active')),
                if (vigentes.isEmpty) EstadoVacio(mensaje: tx('No hay avisos vigentes', 'No active notices'), icono: Icons.check_circle_outline),
                for (final a in vigentes)
                  TarjetaAviso(aviso: a, ruta: cat.rutaPorId[a.idRuta], alTocar: () => _detalle(context, a)),
                if (pasados.isNotEmpty) TituloSeccion(tx('Recientes', 'Recent')),
                for (final a in pasados)
                  Opacity(opacity: 0.6, child: TarjetaAviso(aviso: a, ruta: cat.rutaPorId[a.idRuta], alTocar: () => _detalle(context, a))),
              ],
            ),
          );
        },
      ),
    );
  }

  void _detalle(BuildContext context, Aviso a) {
    final cat = widget.vms.catalogo.cat;
    final paradas = a.paradasAfectadas.map((id) => cat.paradaPorId[id]?.nombre).whereType<String>().toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSuperficie,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${a.tipo.etiqueta} · ${cat.rutaPorId[a.idRuta]?.nombre ?? tx('General', 'General')}',
                style: const TextStyle(color: kTextoSecundario)),
            const SizedBox(height: 12),
            if (a.detalle.isNotEmpty) Text(a.detalle),
            if (paradas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tx('Paradas afectadas: ', 'Affected stops: ') + paradas.join(', ')),
            ],
            const SizedBox(height: 12),
            Text(
              tx('Vigente desde ${fechaCorta(a.vigenteDesde)}', 'Active since ${fechaCorta(a.vigenteDesde)}') +
                  (a.vigenteHasta == null ? '' : tx(' hasta ${fechaCorta(a.vigenteHasta!)}', ' until ${fechaCorta(a.vigenteHasta!)}')),
              style: const TextStyle(color: kTextoSecundario, fontSize: 12),
            ),
            if (a.automatico)
              Text(tx('Aviso automático por un cambio en la ruta', 'Automatic notice from a route change'),
                  style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
