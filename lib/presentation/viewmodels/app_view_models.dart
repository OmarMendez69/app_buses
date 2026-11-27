import '../../core/idioma.dart';
import '../../data/repositorios/admin_repository.dart';
import '../../data/repositorios/comunidad_repository.dart';
import '../../data/repositorios/servicios_externos.dart';
import '../../servicios/seguimiento.dart';
import 'catalogo_vm.dart';
import 'favoritos_vm.dart';
import 'sesion_vm.dart';
import 'viajes_vm.dart';

/// Agrupa los ViewModels y repositorios para pasarlos juntos entre pantallas.
/// Un solo juego vive toda la app: así el estado persiste al navegar.
class AppViewModels {
  final Idioma idioma;
  final SesionVM sesion;
  final CatalogoVM catalogo;
  final FavoritosVM favoritos;
  final ViajesVM viajes;
  final Seguimiento seguimiento;
  final ComunidadRepository comunidad;
  final AdminRepository admin;
  final ServiciosExternos externos;

  const AppViewModels({
    required this.idioma,
    required this.sesion,
    required this.catalogo,
    required this.favoritos,
    required this.viajes,
    required this.seguimiento,
    required this.comunidad,
    required this.admin,
    required this.externos,
  });
}
