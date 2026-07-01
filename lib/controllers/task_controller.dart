import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/task_item.dart';
import '../services/task_storage_service.dart';

class TaskController extends ChangeNotifier {
  TaskController(this._storage, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final TaskStorageService _storage;
  final Uuid _uuid;
  final List<TaskItem> _tasks = [];
  bool _isLoading = true;

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  int get incompleteCount => _tasks.where((task) => !task.isDone).length;
  bool get hasCompletedTasks => _tasks.any((task) => task.isDone);

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();
    final loadedTasks = await _storage.loadTasks();
    _tasks
      ..clear()
      ..addAll(loadedTasks);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveTasks() => _storage.saveTasks(_tasks);

  Future<bool> addTask(String title) async {
    final normalized = title.trim();
    if (!_isValidTitle(normalized)) return false;
    final now = DateTime.now();
    _tasks.insert(
      0,
      TaskItem(
        id: _uuid.v4(),
        title: normalized,
        isDone: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _persistAndNotify();
    return true;
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(
      isDone: !_tasks[index].isDone,
      updatedAt: DateTime.now(),
    );
    await _persistAndNotify();
  }

  Future<bool> updateTaskTitle(String id, String title) async {
    final normalized = title.trim();
    if (!_isValidTitle(normalized)) return false;
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return false;
    _tasks[index] = _tasks[index].copyWith(
      title: normalized,
      updatedAt: DateTime.now(),
    );
    await _persistAndNotify();
    return true;
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    await _persistAndNotify();
  }

  Future<void> clearCompletedTasks() async {
    _tasks.removeWhere((task) => task.isDone);
    await _persistAndNotify();
  }

  bool _isValidTitle(String title) => title.isNotEmpty && title.length <= 80;

  Future<void> _persistAndNotify() async {
    notifyListeners();
    await saveTasks();
  }
}
