package com.sanjaya.jigu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.graphics.BitmapFactory
import java.io.File
import es.antonborri.home_widget.HomeWidgetProvider

class JiguLocationWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.jigu_location_widget)
            val time = data.all["location_sync_time"]?.toString()?.toLongOrNull() ?: 0L
            val age = WidgetRelativeTime.label(time)
            val map = data.getString("location_map_path", "") ?: ""
            views.setImageViewResource(R.id.location_map, R.drawable.lily_mark)
            if (map.isNotEmpty() && File(map).exists()) {
                BitmapFactory.decodeFile(map)?.let { views.setImageViewBitmap(R.id.location_map, it) }
            }
            views.setTextViewText(R.id.location_age, age)

            views.setOnClickPendingIntent(R.id.location_widget_root, JiguWidgetProvider.launch(context, "places"))
            manager.updateAppWidget(id, views)
        }
    }
}
