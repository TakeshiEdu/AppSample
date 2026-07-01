import 'package:flutter/material.dart';

import '../models/task_item.dart';
import 'task_tile.dart';

class TaskList extends StatelessWidget {
  const TaskList({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskItem> tasks;
  final ValueChanged<String> onToggle;
  final ValueChanged<TaskItem> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.task_alt, size: 52),
            SizedBox(height: 12),
            Text('タスクはまだありません'),
            SizedBox(height: 4),
            Text('上の入力欄から最初のタスクを追加しましょう'),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          onToggle: () => onToggle(task.id),
          onEdit: () => onEdit(task),
          onDelete: () => onDelete(task.id),
        );
      },
    );
  }
}
