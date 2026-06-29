package com.flowlog.flowlog

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.util.TypedValue
import android.widget.RemoteViews

/**
 * Home-screen widget stub showing a static espresso-colored pressure sparkline.
 * Live BLE data wiring is intentionally deferred.
 */
class FlowlogWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val COLOR_ESPRESSO = 0xFF6F4E37.toInt()
        private const val COLOR_OUTLINE = 0xFF8A7B6E.toInt()

        private val SPARKLINE_POINTS = floatArrayOf(
            0.08f, 0.72f,
            0.18f, 0.55f,
            0.30f, 0.38f,
            0.42f, 0.22f,
            0.55f, 0.12f,
            0.68f, 0.18f,
            0.80f, 0.30f,
            0.92f, 0.48f,
        )

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.flowlog_widget)
            views.setImageViewBitmap(
                R.id.widget_sparkline,
                createSparklineBitmap(context),
            )

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun createSparklineBitmap(context: Context): Bitmap {
            val width = dpToPx(context, 280f).toInt().coerceAtLeast(1)
            val height = dpToPx(context, 72f).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = COLOR_OUTLINE
                strokeWidth = dpToPx(context, 0.5f)
                alpha = 64
            }
            val horizontalLines = 3
            for (index in 1 until horizontalLines) {
                val y = height * index / horizontalLines.toFloat()
                canvas.drawLine(0f, y, width.toFloat(), y, gridPaint)
            }

            val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = COLOR_ESPRESSO
                alpha = 48
                style = Paint.Style.FILL
            }
            val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = COLOR_ESPRESSO
                strokeWidth = dpToPx(context, 2f)
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }

            val path = Path()
            val fillPath = Path()
            val baselineY = height * 0.92f

            for (index in SPARKLINE_POINTS.indices step 2) {
                val x = SPARKLINE_POINTS[index] * width
                val y = height - (SPARKLINE_POINTS[index + 1] * height * 0.82f) - height * 0.06f
                if (index == 0) {
                    path.moveTo(x, y)
                    fillPath.moveTo(x, baselineY)
                    fillPath.lineTo(x, y)
                } else {
                    path.lineTo(x, y)
                    fillPath.lineTo(x, y)
                }
            }
            fillPath.lineTo(SPARKLINE_POINTS[SPARKLINE_POINTS.size - 2] * width, baselineY)
            fillPath.close()

            canvas.drawPath(fillPath, fillPaint)
            canvas.drawPath(path, linePaint)

            return bitmap
        }

        private fun dpToPx(context: Context, dp: Float): Float =
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                context.resources.displayMetrics,
            )
    }
}