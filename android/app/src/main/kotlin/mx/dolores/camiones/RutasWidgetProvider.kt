package mx.dolores.camiones

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget de inicio: muestra las rutas que sigues con su estado del servicio. */
class RutasWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.rutas_widget).apply {
                setTextViewText(
                    R.id.widget_rutas,
                    widgetData.getString("rutas_texto", "Abre la app y sigue una ruta"),
                )
                setTextViewText(R.id.widget_actualizado, widgetData.getString("actualizado", ""))
                val abrir = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_raiz, abrir)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
