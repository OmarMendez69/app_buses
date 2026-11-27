import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/idioma.dart';
import '../../../core/tiempo.dart';
import '../../../data/repositorios/comunidad_repository.dart';
import '../../../domain/entities/comunidad.dart';
import '../../navigation/navegacion.dart';
import '../../viewmodels/app_view_models.dart';
import '../../widgets/comunes.dart';

const _motivos = ['spam', 'ofensivo', 'falso', 'datos_personales', 'otro'];

String _etiquetaMotivo(String m) => switch (m) {
      'spam' => tx('Spam o publicidad', 'Spam or ads'),
      'ofensivo' => tx('Ofensivo', 'Offensive'),
      'falso' => tx('Información falsa', 'False information'),
      'datos_personales' => tx('Expone datos personales', 'Exposes personal data'),
      _ => tx('Otro', 'Other'),
    };

class PublicacionDetallePage extends StatefulWidget {
  final AppViewModels vms;
  final int idPublicacion;
  const PublicacionDetallePage({super.key, required this.vms, required this.idPublicacion});

  @override
  State<PublicacionDetallePage> createState() => _PublicacionDetallePageState();
}

class _PublicacionDetallePageState extends State<PublicacionDetallePage> {
  Publicacion? _p;
  List<Comentario> _comentarios = [];
  bool _cargando = true;
  String? _error;
  final _texto = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final p = await widget.vms.comunidad.publicacion(widget.idPublicacion);
      final c = await widget.vms.comunidad.comentarios(widget.idPublicacion);
      if (!mounted) return;
      setState(() {
        _p = p;
        _comentarios = c;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeError(e);
          _cargando = false;
        });
      }
    }
  }

  Future<void> _util() async {
    final p = _p!;
    try {
      await widget.vms.comunidad.marcarUtil(p.id, !p.marcadaUtil);
      await _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _comentar() async {
    if (_texto.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    try {
      await widget.vms.comunidad.comentar(_p!.id, _texto.text);
      _texto.clear();
      await _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _denunciar({int? idPublicacion, int? idComentario}) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSuperficie,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tx('¿Por qué lo denuncias?', 'Why are you reporting it?'), style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final m in _motivos) ListTile(title: Text(_etiquetaMotivo(m)), onTap: () => Navigator.pop(c, m)),
          ],
        ),
      ),
    );
    if (motivo == null) return;
    try {
      await widget.vms.comunidad.denunciar(idPublicacion: idPublicacion, idComentario: idComentario, motivo: motivo);
      if (mounted) avisar(context, tx('Gracias. Un administrador lo revisará.', 'Thanks. An admin will review it.'));
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _borrar() async {
    try {
      await widget.vms.comunidad.borrarPublicacion(_p!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = widget.vms.sesion;
    final puede = sesion.puedePublicar;
    final p = _p;
    final esMia = p != null && p.idUsuario != null && p.idUsuario == sesion.perfil?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Publicación', 'Post')),
        actions: [
          if (esMia) IconButton(icon: const Icon(Icons.delete_outline), tooltip: tx('Borrar', 'Delete'), onPressed: _borrar),
          if (p != null && puede && !esMia)
            IconButton(icon: const Icon(Icons.flag_outlined), tooltip: tx('Denunciar', 'Report'), onPressed: () => _denunciar(idPublicacion: p.id)),
        ],
      ),
      body: _cargando
          ? const Cargando()
          : p == null
              ? EstadoVacio(mensaje: _error ?? tx('Esta publicación ya no está disponible', 'This post is no longer available'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(children: [
                            Icon(p.categoria.icono, color: kAmbar),
                            const SizedBox(width: 6),
                            Text(p.categoria.etiqueta, style: const TextStyle(color: kAmbar, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(fechaCorta(p.creadoEn), style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                          ]),
                          const SizedBox(height: 10),
                          Text(p.texto, style: const TextStyle(fontSize: 17)),
                          const SizedBox(height: 8),
                          Text('${p.autor}${p.idRuta != null ? ' · ${widget.vms.catalogo.cat.rutaPorId[p.idRuta]?.nombre ?? ''}' : ''}',
                              style: const TextStyle(color: kTextoSecundario)),
                          if (p.oculta)
                            Text(tx('Oculta mientras un administrador la revisa.', 'Hidden while an admin reviews it.'),
                                style: const TextStyle(color: kAmbar)),
                          const SizedBox(height: 8),
                          Text(tx('Contenido comunitario: no es información oficial.', 'Community content: not official information.'),
                              style: const TextStyle(color: kTextoSecundario, fontSize: 12)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: puede ? _util : null,
                              icon: Icon(p.marcadaUtil ? Icons.thumb_up : Icons.thumb_up_outlined),
                              label: Text('${tx('Útil', 'Helpful')} · ${p.utiles}'),
                            ),
                          ),
                          TituloSeccion(tx('Comentarios (${_comentarios.length})', 'Comments (${_comentarios.length})')),
                          for (final c in _comentarios)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.texto),
                              subtitle: Text('${c.autor} · ${haceCuanto(c.creadoEn)}'),
                              trailing: puede && c.idUsuario != sesion.perfil?.id
                                  ? IconButton(
                                      icon: const Icon(Icons.flag_outlined, size: 18),
                                      onPressed: () => _denunciar(idComentario: c.id),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    if (puede)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _texto,
                                maxLength: 300,
                                decoration: InputDecoration(
                                  hintText: tx('Escribe un comentario', 'Write a comment'),
                                  counterText: '',
                                  filled: true,
                                  fillColor: kSuperficie,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _enviando ? null : _comentar,
                              icon: const Icon(Icons.send, color: kAcento),
                            ),
                          ]),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tx('Crea una cuenta para comentar.', 'Create an account to comment.'),
                            style: const TextStyle(color: kTextoSecundario)),
                      ),
                  ],
                ),
    );
  }
}
