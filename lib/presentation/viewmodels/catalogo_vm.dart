import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositorios/catalogo_repository.dart';
import '../../data/repositorios/comunidad_repository.dart';
import '../../domain/catalogo.dart';
import '../../servicios/seguimiento.dart';

/// Catálogo del transporte en memoria. Primero carga lo guardado en el teléfono
/// (funciona sin internet) y luego lo actualiza desde Supabase.
class CatalogoVM extends ChangeNotifier {
  final CatalogoRepository repo;
  CatalogoVM(this.repo);

  Catalogo cat = Catalogo.vacio();
  bool cargando = false;
  bool desdeCache = false;
  String? error;
  LatLng? ubicacion;

  RealtimeChannel? _canal;
  Timer? _refrescoPendiente;
  Timer? _reloj;
  final _alCambiar = <VoidCallback>[];

  /// Para que otros (favoritos, viajes) recalculen al llegar datos nuevos.
  void alActualizar(VoidCallback f) => _alCambiar.add(f);

  bool _iniciado = false;

  /// Se llama al abrir la app. Si ya se inició (p. ej. al cambiar de idioma), solo refresca.
  Future<void> iniciar() async {
    if (_iniciado) return refrescar();
    _iniciado = true;
    // Cada minuto se recalcula el estado del servicio ("en servicio", "inicia 6:00"...)
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) => notifyListeners());
    final guardado = await repo.desdeCache();
    if (guardado != null) {
      cat = guardado;
      desdeCache = true;
      notifyListeners();
    }
    await refrescar();
    try {
      _canal = repo.escucharCambios((_) {
        _refrescoPendiente?.cancel();
        _refrescoPendiente = Timer(const Duration(seconds: 2), refrescar);
      });
    } catch (e) {
      debugPrint('Realtime: $e');
    }
  }

  Future<void> refrescar() async {
    cargando = true;
    notifyListeners();
    try {
      cat = await repo.descargar();
      desdeCache = false;
      error = null;
      for (final f in _alCambiar) {
        f();
      }
    } catch (e) {
      error = mensajeError(e);
    }
    cargando = false;
    notifyListeners();
  }

  Future<LatLng?> actualizarUbicacion() async {
    final u = await ubicacionActual();
    if (u != null) {
      ubicacion = u;
      notifyListeners();
    }
    return u;
  }

  @override
  void dispose() {
    _canal?.unsubscribe();
    _refrescoPendiente?.cancel();
    _reloj?.cancel();
    super.dispose();
  }
}
