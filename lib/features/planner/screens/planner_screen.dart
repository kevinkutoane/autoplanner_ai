import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/task_controller.dart';
import '../../../core/providers/providers.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final sortedTasks = [...tasks]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Plan"),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: AnimationLimiter(
        child: ReorderableListView.builder(
          key: const Key('planner_list'),
          itemCount: sortedTasks.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;

            final taskList = [...sortedTasks];
            final task = taskList.removeAt(oldIndex);
            taskList.insert(newIndex, task);

            // Recalculate time slots
            final updatedList = <TaskItem>[];
            final start = DateTime.now().copyWith(
              hour: 6,
              minute: 0,
            ); // Default start

            for (int i = 0; i < taskList.length; i++) {
              final newTime = start.add(Duration(hours: i));
              updatedList.add(taskList[i].copyWith(startTime: newTime));
            }

            for (final t in updatedList) {
              ref.read(taskControllerProvider.notifier).updateTask(t);
            }
          },
          itemBuilder: (context, index) {
            final task = sortedTasks[index];
            return KeyedSubtree(
              key: ValueKey(task.id),
              child: AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 300),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: ListTile(
                        title: Text(task.title),
                        subtitle: Text(
                          DateFormat('hh:mm a').format(task.startTime),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final aiService = ref.read(aiServiceProvider);
          final input = await _showInputDialog(context);
          if (input != null && context.mounted) {
            final newTasks = await aiService.parseTasks(input);
            if (newTasks.isEmpty && context.mounted) {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("AI Parsing Failed"),
                  content: const Text(
                    "Sorry, I couldn't understand your input. Please try rephrasing or be more specific.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            } else {
              for (final task in newTasks) {
                ref.read(taskControllerProvider.notifier).addTask(task);
              }
            }
          }
        },
      ),
    );
  }

  Future<String?> _showInputDialog(BuildContext context) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("What's your plan today?"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Gym at 6am, meeting at 10...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Plan"),
          ),
        ],
      ),
    );
  }
}
