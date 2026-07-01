import 'package:flutter_test/flutter_test.dart';
import 'package:simple_tasker/controllers/task_controller.dart';
import 'package:simple_tasker/models/task_item.dart';
import 'package:simple_tasker/services/task_storage_service.dart';

class MemoryTaskStorage implements TaskStorageService {
  List<TaskItem> storedTasks = [];

  @override
  Future<List<TaskItem>> loadTasks() async => List.of(storedTasks);

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    storedTasks = List.of(tasks);
  }
}

void main() {
  late MemoryTaskStorage storage;
  late TaskController controller;

  setUp(() async {
    storage = MemoryTaskStorage();
    controller = TaskController(storage);
    await controller.loadTasks();
  });

  test('adds a trimmed task and persists it', () async {
    expect(await controller.addTask('  牛乳を買う  '), isTrue);
    expect(controller.tasks, hasLength(1));
    expect(controller.tasks.single.title, '牛乳を買う');
    expect(storage.storedTasks, hasLength(1));
  });

  test('does not add an empty task', () async {
    expect(await controller.addTask('   '), isFalse);
    expect(controller.tasks, isEmpty);
  });

  test('toggles a task completion state', () async {
    await controller.addTask('散歩する');
    final id = controller.tasks.single.id;
    await controller.toggleTask(id);
    expect(controller.tasks.single.isDone, isTrue);
  });

  test('deletes a task', () async {
    await controller.addTask('削除するタスク');
    await controller.deleteTask(controller.tasks.single.id);
    expect(controller.tasks, isEmpty);
    expect(storage.storedTasks, isEmpty);
  });
}
