import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'data/datasources/rutas_data_source.dart';
import 'data/datasources/rutas_mock_data_source.dart';
import 'data/repositories/rutas_repository_impl.dart';
import 'domain/entities/ruta_cercana.dart';
import 'domain/repositories/rutas_repository.dart';
import 'domain/usecases/obtener_rutas_cercanas.dart';
import 'presentation/pages/inicio_page.dart';
import 'presentation/viewmodels/inicio_view_model.dart';

/// Inyección de dependencias: aquí se arman las capas.
void main() {
  // Data
  final RutasDataSource fuente = RutasMockDataSource();
  final RutasRepository repositorio = RutasRepositoryImpl(fuente);
  final ReportesDataSource fuenteReportes = ReportesMockDataSource();
  final ReportesRepository repositorioReportes =
      ReportesRepositoryImpl(fuenteReportes);

  // Domain
  final obtenerRutasCercanas = ObtenerRutasCercanas(repositorio);
  final enviarReporteCamion = EnviarReporteCamion(repositorioReportes);

  // Presentation
  final inicioViewModel = InicioViewModel(obtenerRutasCercanas);

  runApp(
    MaterialApp(
      title: 'Camiones Dolores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kFondo,
        colorScheme: const ColorScheme.dark(primary: kAcento),
        useMaterial3: true,
      ),
      home: _InicioConReporte(
        viewModel: inicioViewModel,
        abrirReporte: (context) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReportarCamionPage(
                viewModel: ReportarCamionViewModel(
                  obtenerRutasCercanas,
                  enviarReporteCamion,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

// ============================================================================
//  CONEXIÓN: abre la pantalla nueva desde el botón "Reportar camión" del
//  Inicio sin modificar inicio_page.dart (se coloca una zona táctil encima).
// ============================================================================

class _InicioConReporte extends StatefulWidget {
  final InicioViewModel viewModel;
  final void Function(BuildContext context) abrirReporte;

  const _InicioConReporte({
    required this.viewModel,
    required this.abrirReporte,
  });

  @override
  State<_InicioConReporte> createState() => _InicioConReporteState();
}

class _InicioConReporteState extends State<_InicioConReporte>
    with WidgetsBindingObserver {
  final GlobalKey _clave = GlobalKey();
  Rect? _zonaBoton;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscarBoton());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscarBoton());
  }

  /// Busca en pantalla el botón 'reportar' y guarda su posición.
  void _buscarBoton() {
    if (!mounted) return;
    final contexto = _clave.currentContext;
    if (contexto == null) return;

    Rect? encontrado;
    void visitar(Element e) {
      if (encontrado != null) return;
      final w = e.widget;
      if (w is FloatingActionButton && w.heroTag == 'reportar') {
        final caja = e.renderObject;
        if (caja is RenderBox && caja.hasSize) {
          encontrado = caja.localToGlobal(Offset.zero) & caja.size;
        }
        return;
      }
      e.visitChildren(visitar);
    }

    (contexto as Element).visitChildren(visitar);

    if (encontrado != _zonaBoton) {
      setState(() => _zonaBoton = encontrado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zona = _zonaBoton;
    return Stack(
      children: [
        Positioned.fill(
          child: KeyedSubtree(
            key: _clave,
            child: InicioPage(viewModel: widget.viewModel),
          ),
        ),
        if (zona != null)
          Positioned.fromRect(
            rect: zona,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.abrirReporte(context),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
//  DOMAIN
// ============================================================================

enum TipoReporte { paso, enCamino, retrasado }

class ReporteCamion {
  final String ruta;
  final String parada;
  final TipoReporte tipo;
  final String comentario;

  const ReporteCamion({
    required this.ruta,
    required this.parada,
    required this.tipo,
    required this.comentario,
  });
}

abstract class ReportesRepository {
  Future<void> enviarReporte(ReporteCamion reporte);
}

class EnviarReporteCamion {
  final ReportesRepository _repositorio;

  const EnviarReporteCamion(this._repositorio);

  Future<void> call(ReporteCamion reporte) =>
      _repositorio.enviarReporte(reporte);
}

// ============================================================================
//  DATA
// ============================================================================

abstract class ReportesDataSource {
  Future<void> enviarReporte(Map<String, dynamic> reporte);
}

/// Simula el envío del reporte (sin servidor real todavía).
class ReportesMockDataSource implements ReportesDataSource {
  @override
  Future<void> enviarReporte(Map<String, dynamic> reporte) async {
    await Future.delayed(const Duration(milliseconds: 800));
  }
}

class ReporteModel {
  final String ruta;
  final String parada;
  final String tipo;
  final String comentario;

  const ReporteModel({
    required this.ruta,
    required this.parada,
    required this.tipo,
    required this.comentario,
  });

  factory ReporteModel.fromEntity(ReporteCamion reporte) {
    return ReporteModel(
      ruta: reporte.ruta,
      parada: reporte.parada,
      tipo: reporte.tipo.name,
      comentario: reporte.comentario,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ruta': ruta,
      'parada': parada,
      'tipo': tipo,
      'comentario': comentario,
    };
  }
}

class ReportesRepositoryImpl implements ReportesRepository {
  final ReportesDataSource _fuente;

  const ReportesRepositoryImpl(this._fuente);

  @override
  Future<void> enviarReporte(ReporteCamion reporte) {
    return _fuente.enviarReporte(ReporteModel.fromEntity(reporte).toMap());
  }
}

// ============================================================================
//  PRESENTATION · VIEWMODEL
// ============================================================================

enum EstadoEnvio { inactivo, enviando, enviado, error }

class ReportarCamionViewModel extends ChangeNotifier {
  final ObtenerRutasCercanas _obtenerRutasCercanas;
  final EnviarReporteCamion _enviarReporteCamion;

  ReportarCamionViewModel(
    this._obtenerRutasCercanas,
    this._enviarReporteCamion,
  );

  EstadoCarga _estado = EstadoCarga.cargando;
  EstadoEnvio _estadoEnvio = EstadoEnvio.inactivo;
  List<RutaCercana> _rutas = const [];
  RutaCercana? _rutaSeleccionada;
  TipoReporte _tipo = TipoReporte.paso;
  String _comentario = '';

  EstadoCarga get estado => _estado;
  EstadoEnvio get estadoEnvio => _estadoEnvio;
  List<RutaCercana> get rutas => _rutas;
  RutaCercana? get rutaSeleccionada => _rutaSeleccionada;
  TipoReporte get tipo => _tipo;

  bool get puedeEnviar =>
      _rutaSeleccionada != null && _estadoEnvio != EstadoEnvio.enviando;

  Future<void> cargarRutas() async {
    _estado = EstadoCarga.cargando;
    notifyListeners();
    try {
      _rutas = await _obtenerRutasCercanas();
      _estado = EstadoCarga.exito;
    } catch (_) {
      _estado = EstadoCarga.error;
    }
    notifyListeners();
  }

  void seleccionarRuta(RutaCercana ruta) {
    _rutaSeleccionada = ruta;
    notifyListeners();
  }

  void seleccionarTipo(TipoReporte tipo) {
    _tipo = tipo;
    notifyListeners();
  }

  void cambiarComentario(String texto) {
    _comentario = texto;
  }

  Future<void> enviar() async {
    final ruta = _rutaSeleccionada;
    if (ruta == null) return;

    _estadoEnvio = EstadoEnvio.enviando;
    notifyListeners();
    try {
      await _enviarReporteCamion(
        ReporteCamion(
          ruta: ruta.nombre,
          parada: ruta.parada,
          tipo: _tipo,
          comentario: _comentario.trim(),
        ),
      );
      _estadoEnvio = EstadoEnvio.enviado;
    } catch (_) {
      _estadoEnvio = EstadoEnvio.error;
    }
    notifyListeners();
  }
}

// ============================================================================
//  PRESENTATION · PAGE
// ============================================================================

class ReportarCamionPage extends StatefulWidget {
  final ReportarCamionViewModel viewModel;

  const ReportarCamionPage({super.key, required this.viewModel});

  @override
  State<ReportarCamionPage> createState() => _ReportarCamionPageState();
}

class _ReportarCamionPageState extends State<ReportarCamionPage> {
  EstadoEnvio _ultimoEstadoEnvio = EstadoEnvio.inactivo;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_alCambiarEstado);
    widget.viewModel.cargarRutas();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_alCambiarEstado);
    super.dispose();
  }

  /// Reacciona al resultado del envío (mensaje + volver atrás).
  void _alCambiarEstado() {
    final estado = widget.viewModel.estadoEnvio;
    if (estado == _ultimoEstadoEnvio) return; // evita avisos repetidos
    _ultimoEstadoEnvio = estado;
    if (estado == EstadoEnvio.enviado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias! Reporte enviado')),
      );
      Navigator.of(context).maybePop();
    } else if (estado == EstadoEnvio.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el reporte')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kFondo,
        elevation: 0,
        title: const Text(
          'Reportar camión',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorde),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final vm = widget.viewModel;
            final enviando = vm.estadoEnvio == EstadoEnvio.enviando;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      const _TituloSeccion('¿QUÉ RUTA VISTE?'),
                      const SizedBox(height: 10),
                      _SelectorRuta(viewModel: vm),
                      const SizedBox(height: 14),
                      const _TituloSeccion('¿QUÉ PASÓ?'),
                      const SizedBox(height: 10),
                      _SelectorTipoReporte(
                        seleccionado: vm.tipo,
                        onChanged: vm.seleccionarTipo,
                      ),
                      const SizedBox(height: 20),
                      const _TituloSeccion('DETALLES'),
                      const SizedBox(height: 10),
                      _CampoComentario(onChanged: vm.cambiarComentario),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: vm.puedeEnviar ? vm.enviar : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: kAcento,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: kSuperficie,
                        disabledForegroundColor: kTextoSecundario,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.campaign_outlined),
                      label: Text(enviando ? 'Enviando...' : 'Enviar reporte'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
//  PRESENTATION · WIDGETS
// ============================================================================

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
        color: kTextoSecundario,
      ),
    );
  }
}

class _SelectorRuta extends StatelessWidget {
  final ReportarCamionViewModel viewModel;

  const _SelectorRuta({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    switch (viewModel.estado) {
      case EstadoCarga.cargando:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: kAcento)),
        );
      case EstadoCarga.error:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No se pudieron cargar las rutas',
              style: TextStyle(color: kTextoSecundario),
            ),
          ),
        );
      case EstadoCarga.exito:
        return Column(
          children: [
            for (final ruta in viewModel.rutas) ...[
              _OpcionRuta(
                ruta: ruta,
                seleccionada: viewModel.rutaSeleccionada == ruta,
                onTap: () => viewModel.seleccionarRuta(ruta),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
    }
  }
}

class _OpcionRuta extends StatelessWidget {
  final RutaCercana ruta;
  final bool seleccionada;
  final VoidCallback onTap;

  const _OpcionRuta({
    required this.ruta,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionada ? kAcento.withValues(alpha: 0.12) : kSuperficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: seleccionada ? kAcento : kBorde),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kAcento,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_bus, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ruta.nombre} · ${ruta.recorrido}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ruta.parada,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              seleccionada ? Icons.check_circle : Icons.radio_button_unchecked,
              color: seleccionada ? kAcento : kTextoSecundario,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorTipoReporte extends StatelessWidget {
  final TipoReporte seleccionado;
  final ValueChanged<TipoReporte> onChanged;

  const _SelectorTipoReporte({
    required this.seleccionado,
    required this.onChanged,
  });

  static const _opciones = [
    (TipoReporte.paso, 'Ya pasó', Icons.check_circle_outline),
    (TipoReporte.enCamino, 'Viene en camino', Icons.directions_bus_outlined),
    (TipoReporte.retrasado, 'Va retrasado', Icons.access_time),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (tipo, texto, icono) in _opciones)
          _ChipTipo(
            texto: texto,
            icono: icono,
            activo: tipo == seleccionado,
            onTap: () => onChanged(tipo),
          ),
      ],
    );
  }
}

class _ChipTipo extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _ChipTipo({
    required this.texto,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? kAcento.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? kAcento : kBorde),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: activo ? kAcento : kTextoSecundario),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                color: activo ? kAcento : kTextoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoComentario extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _CampoComentario({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: kSuperficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorde),
      ),
      child: TextField(
        onChanged: onChanged,
        maxLines: 3,
        maxLength: 120,
        decoration: const InputDecoration(
          hintText: 'Comentario (opcional)',
          hintStyle: TextStyle(color: kTextoSecundario),
          border: InputBorder.none,
        ),
      ),
    );
  }
}