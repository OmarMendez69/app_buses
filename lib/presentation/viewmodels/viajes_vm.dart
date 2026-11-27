import 'package:flutter/foundation.dart';

import '../../data/cache_local.dart';
import '../../data/repositorios/sesion_repository.dart';
import '../../domain/entities/viaje.dart';
import '../../servicios/notificaciones.dart';
import 'catalogo_vm.dart';
import 'sesion_vm.dart';

/// Viajes frecuentes con recordatorio de salida.
/// Usuario: se guardan en su cuenta. Visitante: solo en el teléfono.
class ViajesVM extends ChangeNotifier {
  final SesionRepository repo;
  final CacheLocal cache;
  final SesionVM sesion;
  final CatalogoVM catalogo;

  ViajesVM(this.repo, this.cache, this.sesion, this.catalogo) {
    catalogo.alActualizar(_reprogramar);
  }

  List<ViajeGuardado> viajes = [];

  Future<void> cargar() async {
    try {
      if (sesion.conSesion) {
        viajes = (await repo.viajes()).map(ViajeGuardado.fromJson).toList();
        await cache.guardarViajes(viajes.map((v) => v.toJson()).toList());
      } else {
        viajes = (await cache.leerViajes()).map(ViajeGuardado.fromJson).toList();
      }
    } catch (_) {
      viajes = (await cache.leerViajes()).map(ViajeGuardado.fromJson).toList();
    }
    notifyListeners();
    await _reprogramar();
  }

  /// Lanza excepción si se pasa del límite de 10.
  Future<void> guardar(ViajeGuardado v) async {
    if (v.id == null && viajes.length >= 10) throw Exception('Puedes guardar hasta 10 viajes');
    ViajeGuardado guardado;
    if (sesion.conSesion) {
      final id = await repo.guardarViaje(v.toJson());
      guardado = v.copyWith(id: id);
    } else {
      final id = v.id ?? (viajes.isEmpty ? 1 : viajes.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      guardado = v.copyWith(id: id);
    }
    viajes = [...viajes.where((e) => e.id != guardado.id), guardado]..sort((a, b) => a.nombre.compareTo(b.nombre));
    await cache.guardarViajes(viajes.map((e) => e.toJson()).toList());
    notifyListeners();
    await _reprogramar();
  }

  Future<void> borrar(ViajeGuardado v) async {
    if (sesion.conSesion && v.id != null) await repo.borrarViaje(v.id!);
    viajes = viajes.where((e) => e.id != v.id).toList();
    await cache.guardarViajes(viajes.map((e) => e.toJson()).toList());
    notifyListeners();
    await _reprogramar();
  }

  Future<void> alternarRecordatorio(ViajeGuardado v) => guardar(v.copyWith(recordatorio: !v.recordatorio));

  Future<void> _reprogramar() async {
    if (catalogo.cat.vacio) return;
    await Notificaciones.instancia.programarRecordatorios(catalogo.cat, viajes);
  }
}
