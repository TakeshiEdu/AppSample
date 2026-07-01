import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/task_controller.dart';
import '../models/task_item.dart';
import '../widgets/edit_task_dialog.dart';
import '../widgets/task_input.dart';
import '../widgets/task_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _editTask(BuildContext context, TaskItem task) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => EditTaskDialog(task: task),
    );
    if (title != null && context.mounted) {
      await context.read<TaskController>().updateTaskTitle(task.id, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaskController>();
    return Scaffold(
      appBar: AppBar(title: const Text('SimpleTasker')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '未完了のタスクは ${controller.incompleteCount} 件です',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 20),
                          TaskInput(onAdd: controller.addTask),
                          const SizedBox(height: 12),
                          TaskList(
                            tasks: controller.tasks,
                            onToggle: controller.toggleTask,
                            onEdit: (task) => _editTask(context, task),
                            onDelete: controller.deleteTask,
                          ),
                          if (controller.hasCompletedTasks) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: controller.clearCompletedTasks,
                              icon: const Icon(
                                Icons.cleaning_services_outlined,
                              ),
                              label: const Text('完了済みタスクを削除'),
                            ),
                          ],
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
