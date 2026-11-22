package com.bayu.nudge

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Sticky-note home screen widget. The Dart side writes the pinned cards to
 * the shared preferences (`count`, `title_i`, `id_i`); this just renders them.
 * Ticking a row runs a Dart callback in the background (completes the card),
 * tapping the title opens the card in the app.
 */
class NudgeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val count = widgetData.getInt("count", 0).coerceIn(0, MAX_ROWS)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nudge_widget)

            views.setTextViewText(
                R.id.widget_header,
                if (count == 0) "Nudge" else "Nudge · $count belum selesai",
            )
            views.setViewVisibility(
                R.id.widget_empty,
                if (count == 0) View.VISIBLE else View.GONE,
            )

            for (i in 0 until MAX_ROWS) {
                val rowId = ROWS[i]
                if (i >= count) {
                    views.setViewVisibility(rowId, View.GONE)
                    continue
                }
                val cardId = widgetData.getString("id_$i", "") ?: ""
                val title = widgetData.getString("title_$i", "") ?: ""
                views.setViewVisibility(rowId, View.VISIBLE)
                views.setTextViewText(TITLES[i], title)

                // Tick: complete the card without opening the app.
                views.setOnClickPendingIntent(
                    DONES[i],
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("nudge://done/$cardId"),
                    ),
                )
                // Title: open the card.
                views.setOnClickPendingIntent(
                    TITLES[i],
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("nudge://card/$cardId"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        const val MAX_ROWS = 5
        private val ROWS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
        private val DONES = intArrayOf(R.id.done_0, R.id.done_1, R.id.done_2, R.id.done_3, R.id.done_4)
        private val TITLES = intArrayOf(R.id.title_0, R.id.title_1, R.id.title_2, R.id.title_3, R.id.title_4)
    }
}
