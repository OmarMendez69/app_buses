/// Roles del modelo de dominio: el alumno y el visitante reportan,
/// el admin gestiona rutas.
enum Rol {
  admin('Administrador'),
  alumno('Alumno'),
  visitante('Visitante');

  final String etiqueta;
  const Rol(this.etiqueta);
}

class Usuario {
  final String nombre;
  final String correo;
  final String contrasena;
  final Rol rol;

  /// Qué tan confiable es el usuario al reportar (modelo: Usuario.reputacion).
  final int reputacion;

  const Usuario({
    required this.nombre,
    required this.correo,
    required this.contrasena,
    required this.rol,
    this.reputacion = 0,
  });
}
