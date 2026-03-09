import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../core/models/task_model.dart';

/// Pushes today's top-3 pending tasks and completion stats to the home
/// screen widget on Android / iOS.
///
/// You must call [update] from TaskController / SettingsController after
/// any task change so the widget reflects the latest state.
class HomeWidgetService {
  static const _appId = 'com.example.autoplanner_ai';
  static const _androidWidgetName = 'AutoPlannerWidgetProvider';
  static const _iOSWidgetName = 'AutoPlannerWidget';

  static Future<void> update(List<TaskItem> allTasks) async {
    try {
      await HomeWidget.setAppGroupId('group.autoplanner_ai');

      final now = DateTime.now();
      final today =
          allTasks
              .where(
                (t) =>
                    t.startTime.year == now.year &&
                    t.startTime.month == now.month &&
                    t.startTime.day == now.day,
              )
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

      final completed = today.where((t) => t.isCompleted).length;
      final total = today.length;

      await HomeWidget.saveWidgetData<int>('completed', completed);
      await HomeWidget.saveWidgetData<int>('total', total);

      // Top 3 pending
      final pending = today.where((t) => !t.isCompleted).take(3).toList();
      for (var i = 0; i < 3; i++) {
        if (i < pending.length) {
          await HomeWidget.saveWidgetData<String>('task_$i', pending[i].title);
          // Format hour:minute
          final h = pending[i].startTime.hour;
          final m = pending[i].startTime.minute.toString().padLeft(2, '0');
          final ampm = h < 12 ? 'AM' : 'PM';
          final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
          await HomeWidget.saveWidgetData<String>(
            'task_${i}_time',
            '$h12:$m $ampm',
          );
        } else {
          await HomeWidget.saveWidgetData<String>('task_$i', '');
          await HomeWidget.saveWidgetData<String>('task_${i}_time', '');
        }
      }

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
        qualifiedAndroidName: '$_appId.$_androidWidgetName',
      );
    } catch (e) {
      if (kDebugMode) print('HomeWidgetService: $e');
    }
  }
}
