package com.kevinkutoane.autoplannerai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AutoPlannerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.autoplanner_widget)

            // Tap the widget to open the app
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            // Stats row
            val completed = widgetData.getInt("completed", 0)
            val total = widgetData.getInt("total", 0)
            views.setTextViewText(R.id.widget_stats, "$completed / $total done")

            // Task rows 0–2
            val taskKeys = listOf("task_0", "task_1", "task_2")
            val timeKeys = listOf("task_0_time", "task_1_time", "task_2_time")
            val taskViewIds = listOf(R.id.task_title_0, R.id.task_title_1, R.id.task_title_2)
            val timeViewIds = listOf(R.id.task_time_0, R.id.task_time_1, R.id.task_time_2)

            for (i in taskKeys.indices) {
                val title = widgetData.getString(taskKeys[i], "") ?: ""
                val time = widgetData.getString(timeKeys[i], "") ?: ""
                views.setTextViewText(taskViewIds[i], title)
                views.setTextViewText(timeViewIds[i], time)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
