import 'package:flutter_test/flutter_test.dart';
import 'package:simple_tasker/models/task_item.dart';

void main() {
  test('TaskItem can round-trip through JSON', () {
    final now = DateTime.utc(2026, 7, 1, 9, 30);
    final task = TaskItem(
      id: 'task-1',
      title: 'テストを書く',
      isDone: true,
      createdAt: now,
      updatedAt: now,
    );

    final restored = TaskItem.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.isDone, isTrue);
    expect(restored.createdAt, now);
    expect(restored.updatedAt, now);
  });
}
