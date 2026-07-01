import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_item.dart';

abstract class TaskStorageService {
  Future<List<TaskItem>> loadTasks();
  Future<void> saveTasks(List<TaskItem> tasks);
}

class SharedPreferencesTaskStorageService implements TaskStorageService {
  static const storageKey = 'simple_tasker_tasks_v1';

  @override
  Future<List<TaskItem>> loadTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(storageKey);
    if (value == null || value.isEmpty) return [];

    try {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  @override
  Future<void> saveTasks(List<TaskItem> tasks) async {
    final preferences = await SharedPreferences.getInstance();
    final value = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await preferences.setString(storageKey, value);
  }
}
