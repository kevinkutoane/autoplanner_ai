import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/task_model.dart';
import '../controllers/task_controller.dart';

class TaskTile extends ConsumerWidget {
  final TaskItem task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = TimeOfDay.fromDateTime(task.startTime).format(context);

    return Dismissible(
      key: Key(task.id),
      background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) {
        ref.read(taskControllerProvider.notifier).removeTask(task.id);
      },
      child: ListTile(
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(time),
        trailing: IconButton(
          icon: Icon(
            task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: task.isCompleted ? Colors.green : null,
          ),
          onPressed: () {
            final updated = task.copyWith(isCompleted: !task.isCompleted);
            ref.read(taskControllerProvider.notifier).updateTask(updated);
          },
        ),
      ),
    );
  }
}
