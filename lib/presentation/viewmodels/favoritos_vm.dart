import 'package:flutter/foundation.dart';

import '../../data/cache_local.dart';
import '../../data/repositorios/sesion_repository.dart';
import '../../servicios/notificaciones.dart';
import '../../servicios/widget_inicio.dart';
import 'catalogo_vm.dart';
import 'sesion_vm.dart';

/// Rutas que sigues. Seguir una ruta = recibir sus avisos, verla en el widget
/// y recibir el aviso de último camión.
class FavoritosVM extends ChangeNotifier {
  final SesionRepository repo;
  final CacheLocal cache;
  final SesionVM sesion;
  final CatalogoVM catalogo;

  FavoritosVM(this.repo, this.cache, this.sesion, this.catalogo) {
    catalogo.alActualizar(() => aplicarEfectos());
  }

  Set<int> ids = {};
  Map<String, bool> notifVisitante = {'rutas': true, 'generales': true};
  int ultimoCamionMin = 40;

  bool sigue(int idRuta) => ids.contains(idRuta);

  bool get notifRutas => sesion.perfil?.notifRutas ?? notifVisitante['rutas'] ?? true;
  bool get notifGenerales => sesion.perfil?.notifGenerales ?? notifVisitante['generales'] ?? true;

  Future<void> cargar() async {
    final antes = {...ids}; // para cancelar suscripciones de la sesión anterior
    ids = await cache.leerFavoritos();
    if (sesion.conSesion) {
      try {
        final remotos = await repo.favoritos();
        // Lo que se siguió como visitante se sube a la cuenta.
        for (final id in ids.difference(remotos)) {
          await repo.agregarFavorito(id);
        }
        ids = {...remotos, ...ids};
        await cache.guardarFavoritos(ids);
      } catch (e) {
        debugPrint('Favoritos: $e');
      }
    }
    notifVisitante = await cache.leerNotifVisitante();
    ultimoCamionMin = await cache.ultimoCamionMin();
    notifyListeners();
    await aplicarEfectos(antes: antes);
  }

  Future<void> alternar(int idRuta) async {
    final antes = {...ids};
    if (!ids.remove(idRuta)) ids.add(idRuta);
    notifyListeners();
    await cache.guardarFavoritos(ids);
    if (sesion.conSesion) {
      try {
        if (ids.contains(idRuta)) {
          await repo.agregarFavorito(idRuta);
        } else {
          await repo.quitarFavorito(idRuta);
        }
      } catch (e) {
        debugPrint('Favoritos: $e');
      }
    }
    await aplicarEfectos(antes: antes);
  }

  Future<void> cambiarNotifVisitante({bool? rutas, bool? generales}) async {
    if (rutas != null) notifVisitante['rutas'] = rutas;
    if (generales != null) notifVisitante['generales'] = generales;
    await cache.guardarNotifVisitante(notifVisitante);
    notifyListeners();
    await aplicarEfectos();
  }

  Future<void> cambiarUltimoCamion(int minutos) async {
    ultimoCamionMin = minutos;
    await cache.guardarUltimoCamionMin(minutos);
    notifyListeners();
    await aplicarEfectos();
  }

  /// Topics de notificación, último camión y widget.
  Future<void> aplicarEfectos({Set<int> antes = const {}}) async {
    final n = Notificaciones.instancia;
    await n.sincronizarTopics(rutas: ids, antes: antes, rutasOn: notifRutas, generalesOn: notifGenerales);
    if (!catalogo.cat.vacio) {
      await n.programarUltimoCamion(catalogo.cat, ids, ultimoCamionMin);
      await WidgetInicio.actualizar(catalogo.cat, ids);
    }
  }
}
