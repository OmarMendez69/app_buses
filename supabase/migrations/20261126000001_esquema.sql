-- =====================================================================
-- Camiones Dolores · Sistema de Información de Transporte
-- Migración 1: tipos, tablas, restricciones e índices
-- Base de datos: PostgreSQL 15+ (Supabase)
-- =====================================================================

create extension if not exists btree_gist;

-- ---------------------------------------------------------------------
-- Valores controlados
-- ---------------------------------------------------------------------
create type public.rol_usuario      as enum ('usuario', 'admin');
create type public.estado_cuenta    as enum ('activa', 'suspendida');
create type public.sentido          as enum ('ida', 'vuelta', 'circuito');
create type public.tipo_dia         as enum ('laborable', 'sabado', 'domingo_festivo');
create type public.tipo_evento      as enum ('entrada', 'salida', 'cambio_turno', 'tianguis', 'otro');
create type public.fuente_dato      as enum ('oficial', 'concesionario', 'municipio', 'institucion', 'levantamiento');
create type public.tipo_aviso       as enum ('desvio', 'suspension', 'cambio_horario', 'cambio_recorrido', 'parada_cerrada', 'general');
create type public.categoria_pub    as enum ('retraso', 'unidad_llena', 'desvio', 'incidente', 'no_paso', 'objeto_perdido', 'pregunta', 'general');
create type public.estado_contenido as enum ('visible', 'oculto');
create type public.estado_denuncia  as enum ('pendiente', 'procedente', 'improcedente');
create type public.categoria_lugar  as enum ('educacion', 'trabajo', 'salud', 'gobierno', 'turismo', 'comercio', 'transporte');

-- Rango de horas para impedir franjas empalmadas
create type public.rango_hora as range (subtype = time);

-- ---------------------------------------------------------------------
-- Usuarios
-- ---------------------------------------------------------------------
create table public.perfil (
  id               uuid primary key references auth.users (id) on delete cascade,
  nombre           varchar(100) not null check (length(trim(nombre)) >= 2),
  rol              public.rol_usuario   not null default 'usuario',
  estado           public.estado_cuenta not null default 'activa',
  notif_rutas      boolean not null default true,
  notif_generales  boolean not null default true,
  notif_respuestas boolean not null default true,
  idioma           varchar(2) not null default 'es' check (idioma in ('es', 'en')),
  creado_en        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Núcleo del transporte (datos oficiales capturados por el admin)
-- ---------------------------------------------------------------------
create table public.ruta (
  id_ruta            serial primary key,
  nombre             varchar(80)  not null,
  color              char(7)      not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  tarifa             numeric(6,2) not null check (tarifa >= 0),
  tarifa_estudiante  numeric(6,2) check (tarifa_estudiante >= 0),
  tarifa_inapam      numeric(6,2) check (tarifa_inapam >= 0),
  fuente_tarifas     public.fuente_dato,
  letrero            varchar(60),
  descripcion_unidad varchar(120),
  foto_unidad        text,
  concesionario      varchar(100),
  activa             boolean not null default false,
  revisada_en        date not null default current_date,
  actualizado_en     timestamptz not null default now(),
  constraint tarifas_con_fuente check (
    (tarifa_estudiante is null and tarifa_inapam is null) or fuente_tarifas is not null
  )
);
create unique index ruta_nombre_unico on public.ruta (lower(nombre));

-- trazado: arreglo JSON de puntos [lng, lat] en orden de recorrido
create table public.recorrido (
  id_recorrido serial primary key,
  id_ruta      int not null references public.ruta (id_ruta) on delete cascade,
  sentido      public.sentido not null,
  trazado      jsonb not null default '[]'::jsonb check (jsonb_typeof(trazado) = 'array'),
  unique (id_ruta, sentido)
);

create table public.parada (
  id_parada  serial primary key,
  nombre     varchar(100) not null,
  referencia varchar(150),
  latitud    numeric(9,6) not null,
  longitud   numeric(9,6) not null,
  activa     boolean not null default true,
  -- Recuadro amplio alrededor del municipio de Dolores Hidalgo, Gto.
  constraint parada_en_municipio check (latitud between 20.80 and 21.55 and longitud between -101.40 and -100.55)
);

create table public.recorrido_parada (
  id_recorrido     int not null references public.recorrido (id_recorrido) on delete cascade,
  id_parada        int not null references public.parada (id_parada),
  orden            smallint not null check (orden >= 1),
  min_desde_inicio smallint check (min_desde_inicio between 0 and 300),
  primary key (id_recorrido, id_parada),
  unique (id_recorrido, orden)
);

create table public.franja_servicio (
  id_franja      serial primary key,
  id_recorrido   int not null references public.recorrido (id_recorrido) on delete cascade,
  tipo_dia       public.tipo_dia not null,
  hora_inicio    time not null,
  hora_fin       time not null,
  frecuencia_min smallint not null check (frecuencia_min between 1 and 120),
  frecuencia_max smallint not null check (frecuencia_max between 1 and 120),
  fuente         public.fuente_dato not null default 'levantamiento',
  actualizado_en timestamptz not null default now(),
  check (hora_inicio < hora_fin),
  check (frecuencia_min <= frecuencia_max),
  constraint franjas_sin_empalme exclude using gist (
    id_recorrido with =,
    tipo_dia with =,
    public.rango_hora(hora_inicio, hora_fin) with &&
  )
);

create table public.lugar (
  id_lugar  serial primary key,
  nombre    varchar(100) not null,
  categoria public.categoria_lugar not null,
  latitud   numeric(9,6) not null,
  longitud  numeric(9,6) not null,
  activo    boolean not null default true,
  constraint lugar_en_municipio check (latitud between 20.80 and 21.55 and longitud between -101.40 and -100.55)
);

-- Sustituye a HoraPico: hechos verificables ("la UTNG entra a las 7:00")
create table public.horario_lugar (
  id_horario    serial primary key,
  id_lugar      int not null references public.lugar (id_lugar) on delete cascade,
  tipo_dia      public.tipo_dia not null,
  dia_semana    smallint check (dia_semana between 1 and 7), -- 1 = lunes; solo para eventos de un día (tianguis)
  hora          time not null,
  evento        public.tipo_evento not null,
  descripcion   varchar(80),
  fuente        public.fuente_dato not null,
  verificado_en date not null default current_date
);
create unique index horario_lugar_unico
  on public.horario_lugar (id_lugar, tipo_dia, coalesce(dia_semana, 0), hora, evento);

create table public.aviso_servicio (
  id_aviso      serial primary key,
  id_ruta       int references public.ruta (id_ruta) on delete cascade, -- null = aviso general
  tipo          public.tipo_aviso not null,
  titulo        varchar(80) not null,
  detalle       text not null default '',
  vigente_desde timestamptz not null default now(),
  vigente_hasta timestamptz,
  automatico    boolean not null default false,
  notificar     boolean not null default true,
  notificado    boolean not null default false,
  creado_por    uuid references public.perfil (id) on delete set null,
  creado_en     timestamptz not null default now(),
  check (vigente_hasta is null or vigente_hasta > vigente_desde)
);
create index aviso_vigencia on public.aviso_servicio (vigente_desde, vigente_hasta);

create table public.aviso_parada (
  id_aviso  int not null references public.aviso_servicio (id_aviso) on delete cascade,
  id_parada int not null references public.parada (id_parada),
  primary key (id_aviso, id_parada)
);

create table public.dia_especial (
  fecha             date primary key,
  nombre            varchar(80) not null,
  tipo_dia_aplicado public.tipo_dia not null,
  id_aviso          int references public.aviso_servicio (id_aviso) on delete set null
);

-- ---------------------------------------------------------------------
-- Usuarios y comunidad
-- ---------------------------------------------------------------------
create table public.dispositivo (
  token_fcm      text primary key,
  id_usuario     uuid not null references public.perfil (id) on delete cascade,
  plataforma     varchar(10) not null default 'android',
  actualizado_en timestamptz not null default now()
);

create table public.favorito (
  id_usuario uuid not null references public.perfil (id) on delete cascade,
  id_ruta    int  not null references public.ruta (id_ruta) on delete cascade,
  creado_en  timestamptz not null default now(),
  primary key (id_usuario, id_ruta)
);

create table public.viaje_guardado (
  id_viaje         serial primary key,
  id_usuario       uuid not null references public.perfil (id) on delete cascade,
  nombre           varchar(40) not null,
  origen_lat       numeric(9,6) not null,
  origen_lng       numeric(9,6) not null,
  origen_nombre    varchar(100) not null,
  destino_lat      numeric(9,6) not null,
  destino_lng      numeric(9,6) not null,
  destino_nombre   varchar(100) not null,
  dias             smallint[] not null default '{1,2,3,4,5}',
  llegar_antes_de  time not null,
  recordatorio     boolean not null default true,
  check (dias <@ array[1,2,3,4,5,6,7]::smallint[] and cardinality(dias) >= 1)
);

create table public.publicacion (
  id_publicacion serial primary key,
  id_usuario     uuid references public.perfil (id) on delete set null, -- null = cuenta eliminada
  categoria      public.categoria_pub not null,
  texto          varchar(500) not null check (length(trim(texto)) >= 3),
  id_ruta        int references public.ruta (id_ruta) on delete set null,
  id_parada      int references public.parada (id_parada) on delete set null,
  estado         public.estado_contenido not null default 'visible',
  creado_en      timestamptz not null default now()
);
create index publicacion_fecha on public.publicacion (creado_en desc);

create table public.comentario (
  id_comentario  serial primary key,
  id_publicacion int not null references public.publicacion (id_publicacion) on delete cascade,
  id_usuario     uuid references public.perfil (id) on delete set null,
  texto          varchar(300) not null check (length(trim(texto)) >= 1),
  estado         public.estado_contenido not null default 'visible',
  creado_en      timestamptz not null default now()
);

create table public.voto_util (
  id_publicacion int  not null references public.publicacion (id_publicacion) on delete cascade,
  id_usuario     uuid not null references public.perfil (id) on delete cascade,
  primary key (id_publicacion, id_usuario)
);

create table public.denuncia (
  id_denuncia    serial primary key,
  id_publicacion int  references public.publicacion (id_publicacion) on delete cascade,
  id_comentario  int  references public.comentario (id_comentario) on delete cascade,
  id_usuario     uuid not null references public.perfil (id) on delete cascade,
  motivo         varchar(30) not null,
  estado         public.estado_denuncia not null default 'pendiente',
  resuelta_por   uuid references public.perfil (id) on delete set null,
  resuelta_en    timestamptz,
  creado_en      timestamptz not null default now(),
  check ((id_publicacion is null) <> (id_comentario is null))
);
create unique index denuncia_unica_pub on public.denuncia (id_usuario, id_publicacion) where id_publicacion is not null;
create unique index denuncia_unica_com on public.denuncia (id_usuario, id_comentario) where id_comentario is not null;

create table public.bitacora_admin (
  id         bigserial primary key,
  id_admin   uuid references public.perfil (id) on delete set null,
  accion     varchar(20) not null,
  entidad    varchar(30) not null,
  id_entidad text,
  detalle    jsonb,
  creado_en  timestamptz not null default now()
);

-- Caché interna de las Edge Functions (OpenRouteService y Nominatim). Sin acceso desde la app.
create table public.cache_api (
  clave     text primary key,
  respuesta jsonb not null,
  creado_en timestamptz not null default now()
);
