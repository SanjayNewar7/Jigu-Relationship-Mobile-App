package com.sanjaya.jigu

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.net.Uri
import android.view.View
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class JiguWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.sanjaya.jigu.NEXT" || intent.action == "com.sanjaya.jigu.PREV") {
            val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
            if (id == -1) return
            val data = HomeWidgetPlugin.getData(context)
            val step = if (intent.action!!.endsWith("NEXT")) 1 else -1
            data.edit().putInt("index_$id", data.getInt("index_$id", 0) + step).apply()
            onUpdate(context, AppWidgetManager.getInstance(context), intArrayOf(id), data)
        }
    }
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val photos = mutableListOf<JSONObject>()
        try {
            val all = JSONArray(data.getString("photos", "[]"))
            for (i in 0 until all.length()) {
                val item = all.getJSONObject(i)
                if (item.optLong("expires") > System.currentTimeMillis() && File(item.optString("path")).exists()) photos.add(item)
            }
        } catch (error: Exception) { Log.w("JiguWidget", "Invalid photo manifest", error) }
        Log.i("JiguWidget", "Rendering ${photos.size} cached photos for ${ids.size} widgets")
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.jigu_widget)
            val index = if (photos.isEmpty()) 0 else Math.floorMod(data.getInt("index_$id", 0), photos.size)
            data.edit().putInt("index_$id", index).apply()
            var rendered = false
            if (photos.isNotEmpty()) {
                val path = photos[index].getString("path")
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, bounds)
                var sample = 1
                while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 2048) sample *= 2
                BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })?.let { decoded ->
                    val display = context.resources.displayMetrics
                    val pixelBudget = (display.widthPixels.toLong() * display.heightPixels * .8).toLong()
                    val scale = kotlin.math.sqrt(pixelBudget.toDouble() / (decoded.width.toLong() * decoded.height)).coerceAtMost(1.0)
                    val it = if (scale < 1) Bitmap.createScaledBitmap(decoded, (decoded.width * scale).toInt().coerceAtLeast(1), (decoded.height * scale).toInt().coerceAtLeast(1), true) else decoded
                    views.setImageViewBitmap(R.id.moment_image, it)
                    // A tiny filtered copy creates a frosted photo backdrop without
                    // depending on unsupported launcher wallpaper blur APIs.
                    val stripHeight = (it.height * .22f).toInt().coerceAtLeast(1)
                    val strip = Bitmap.createBitmap(it, 0, it.height - stripHeight, it.width, stripHeight)
                    val tiny = Bitmap.createScaledBitmap(strip, 24, 6, true)
                    val frost = Bitmap.createScaledBitmap(tiny, 480, 120, true)
                    views.setImageViewBitmap(R.id.moment_frost, frost)
                    rendered = true
                }
            }
            if (!rendered) {
                views.setImageViewResource(R.id.moment_image, R.drawable.lily_mark)
                views.setViewVisibility(R.id.moment_frost, View.GONE)
            } else views.setViewVisibility(R.id.moment_frost, View.VISIBLE)
            views.setTextViewText(R.id.photo_count, if (photos.isEmpty()) "Share a moment in Jigu" else "${index + 1} / ${photos.size} - our moments")
            views.setOnClickPendingIntent(R.id.moment_image, launch(context, "moments"))
            for ((button, action) in listOf(R.id.photo_next to "NEXT", R.id.photo_previous to "PREV")) {
                views.setViewVisibility(button, if (photos.size > 1) View.VISIBLE else View.GONE)
                val intent = Intent(context, JiguWidgetProvider::class.java).setAction("com.sanjaya.jigu.$action").putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                views.setOnClickPendingIntent(button, PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            manager.updateAppWidget(id, views)
        }
    }
    companion object {
        fun launch(context: Context, page: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).setAction("es.antonborri.home_widget.action.LAUNCH").setData(Uri.parse("jigu://$page")).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            return PendingIntent.getActivity(context, page.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
