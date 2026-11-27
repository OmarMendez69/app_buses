# Reglas para la versión release (R8 reduce y renombra clases; sin esto
# algunas librerías truenan al abrir la app aunque en debug funcionen).
# Flutter carga este archivo solo desde android/app/proguard-rules.pro.

# Notificaciones locales (último camión, recordatorios, alarma de bajada).
# Guarda las notificaciones programadas con Gson, que necesita sus clases intactas.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Widget de inicio y código propio de la app (MainActivity, RutasWidgetProvider).
-keep class es.antonborri.home_widget.** { *; }
-keep class mx.dolores.camiones.** { *; }

# Ubicación (seguimiento del viaje con servicio en primer plano).
-keep class com.baseflow.geolocator.** { *; }

# Firebase Messaging (notificaciones de avisos).
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn com.google.android.play.core.**

# WorkManager (lo usa el widget de inicio) guarda sus tareas en una base Room.
# Room crea "WorkDatabase_Impl" por nombre: si R8 la borra o renombra, la app
# truena al abrir con "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**
