import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/idioma.dart';
import '../../core/tiempo.dart';
import '../../domain/catalogo.dart';
import '../../domain/entities/transporte.dart';

/// Campo de formulario con el estilo oscuro de la app.
class CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String etiqueta;
  final IconData icono;
  final String? Function(String?)? validator;
  final bool oculto;
  final TextInputType? teclado;
  final Widget? sufijo;
  final int lineas;
  final int? maximo;

  const CampoTexto({
    super.key,
    required this.controller,
    required this.etiqueta,
    required this.icono,
    this.validator,
    this.oculto = false,
    this.teclado,
    this.sufijo,
    this.lineas = 1,
    this.maximo,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return TextFormField(
      controller: controller,
      obscureText: oculto,
      keyboardType: teclado,
      validator: validator,
      maxLines: oculto ? 1 : lineas,
      maxLength: maximo,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: kTextoSecundario),
        prefixIcon: Icon(icono, color: kAcento),
        suffixIcon: sufijo,
        filled: true,
        fillColor: kSuperficie,
        enabledBorder: borde(kBorde),
        focusedBorder: borde(kAcento),
        errorBorder: borde(Colors.redAccent),
        focusedErrorBorder: borde(Colors.redAccent),
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  final String texto;
  final Widget? accion;
  const TituloSeccion(this.texto, {super.key, this.accion});

  @override
  Widget build(BuildContext context) {
    final t = Text(
      texto.toUpperCase(),
      style: const TextStyle(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w600, color: kTextoSecundario),
    );
    if (accion == null) return Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: t);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(children: [Expanded(child: t), accion!]),
    );
  }
}

/// Mensaje centrado para listas sin elementos.
class EstadoVacio extends StatelessWidget {
  final String mensaje;
  final IconData icono;
  const EstadoVacio({super.key, required this.mensaje, this.icono = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: kTextoSecundario),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: kTextoSecundario)),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta con un número grande y su etiqueta (dashboard del admin).
class TarjetaMetrica extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final VoidCallback? alTocar;
  const TarjetaMetrica({super.key, required this.icono, required this.valor, required this.etiqueta, this.alTocar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSuperficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: kAcento),
            const SizedBox(height: 8),
            Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(etiqueta, style: const TextStyle(fontSize: 12, color: kTextoSecundario)),
          ],
        ),
      ),
    );
  }
}

/// "En servicio · cada 10–15 min" / "Fuera de servicio · inicia 06:00"
String textoEstado(EstadoServicio e) {
  if (e.enServicio) {
    return tx('En servicio · cada ${rangoMinutos(e.frecuenciaMin!, e.frecuenciaMax!)}',
        'In service · every ${rangoMinutos(e.frecuenciaMin!, e.frecuenciaMax!)}');
  }
  if (e.proximoInicio != null) {
    return tx('Fuera de servicio · inicia ${textoHora(e.proximoInicio!)}', 'Not running · starts ${textoHora(e.proximoInicio!)}');
  }
  if (e.inicioManana != null) {
    return tx('Terminó por hoy · mañana inicia ${textoHora(e.inicioManana!)}', 'Done for today · starts tomorrow ${textoHora(e.inicioManana!)}');
  }
  return tx('Sin servicio hoy', 'No service today');
}

Color colorEstado(EstadoServicio e) => e.enServicio ? kVerde : kTextoSecundario;

/// Barra de color de la ruta + nombre + estado. Se usa en todas las listas de rutas.
class TarjetaRuta extends StatelessWidget {
  final Ruta ruta;
  final EstadoServicio estado;
  final String? detalle;
  final Widget? accion;
  final VoidCallback? alTocar;

  const TarjetaRuta({super.key, required this.ruta, required this.estado, this.detalle, this.accion, this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 52,
                decoration: BoxDecoration(color: colorDesdeHex(ruta.color), borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ruta.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (detalle != null)
                      Text(detalle!, style: const TextStyle(color: kTextoSecundario, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(textoEstado(estado), style: TextStyle(color: colorEstado(estado), fontSize: 13)),
                  ],
                ),
              ),
              if (accion != null) accion!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de un aviso de servicio.
class TarjetaAviso extends StatelessWidget {
  final Aviso aviso;
  final Ruta? ruta;
  final VoidCallback? alTocar;
  const TarjetaAviso({super.key, required this.aviso, this.ruta, this.alTocar});

  @override
  Widget build(BuildContext context) {
    final color = aviso.tipo == TipoAviso.suspension ? kAcento : kAmbar;
    return Card(
      child: ListTile(
        onTap: alTocar,
        leading: Icon(Icons.campaign_outlined, color: color),
        title: Text(aviso.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            aviso.tipo.etiqueta,
            if (ruta != null) ruta!.nombre else tx('General', 'General'),
            haceCuanto(aviso.creadoEn),
          ].join(' · '),
        ),
      ),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: kAcento));
}

/// Aviso visible cuando se está mostrando lo guardado en el teléfono.
class BannerSinConexion extends StatelessWidget {
  final DateTime actualizado;
  const BannerSinConexion({super.key, required this.actualizado});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: kAmbar.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          tx('Sin conexión · datos guardados del ${fechaCorta(actualizado)}', 'Offline · data saved on ${fechaCorta(actualizado)}'),
          style: const TextStyle(color: kAmbar, fontSize: 12),
        ),
      );
}

String quitarAcentos(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunAEIOUUN';
  var r = s;
  for (var i = 0; i < de.length; i++) {
    r = r.replaceAll(de[i], a[i]);
  }
  return r.toLowerCase();
}
