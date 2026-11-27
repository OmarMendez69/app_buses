import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/idioma.dart';
import 'data/cache_local.dart';
import 'data/repositorios/admin_repository.dart';
import 'data/repositorios/catalogo_repository.dart';
import 'data/repositorios/comunidad_repository.dart';
import 'data/repositorios/servicios_externos.dart';
import 'data/repositorios/sesion_repository.dart';
import 'presentation/viewmodels/app_view_models.dart';
import 'presentation/viewmodels/catalogo_vm.dart';
import 'presentation/viewmodels/favoritos_vm.dart';
import 'presentation/viewmodels/sesion_vm.dart';
import 'presentation/viewmodels/viajes_vm.dart';
import 'servicios/notificaciones.dart';
import 'servicios/seguimiento.dart';

/// Inyección de dependencias: aquí se arman las capas (data → domain → presentation).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Config.completa) {
    runApp(const _FaltaConfig());
    return;
  }

  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseAnonKey);
  final db = Supabase.instance.client;

  final idioma = Idioma();
  await idioma.cargar();
  await Notificaciones.instancia.iniciar();

  // Data
  final cache = CacheLocal();
  final sesionRepo = SesionRepository(db);

  // Presentation
  final sesion = SesionVM(sesionRepo, cache, idioma);
  final catalogo = CatalogoVM(CatalogoRepository(db, cache));
  final vms = AppViewModels(
    idioma: idioma,
    sesion: sesion,
    catalogo: catalogo,
    favoritos: FavoritosVM(sesionRepo, cache, sesion, catalogo),
    viajes: ViajesVM(sesionRepo, cache, sesion, catalogo),
    seguimiento: Seguimiento(),
    comunidad: ComunidadRepository(db),
    admin: AdminRepository(db),
    externos: ServiciosExternos(db),
  );

  runApp(CamionesApp(vms: vms));
}

class _FaltaConfig extends StatelessWidget {
  const _FaltaConfig();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Falta la configuración de Supabase.\n\n'
                'Ejecuta la app así:\nflutter run --dart-define-from-file=config.json\n\n'
                '(Ver GUIA.md, paso 5)',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
