import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/extraction_project.dart';

class ProjectRepository {
  static const _key = 'extraction_projects_v1';

  Future<List<ExtractionProject>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? const <String>[];
    final projects = <ExtractionProject>[];
    for (final entry in entries) {
      try {
        projects.add(
          ExtractionProject.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } on Object {
        // Ignore a single damaged history entry instead of hiding all history.
      }
    }
    return projects;
  }

  Future<void> save(List<ExtractionProject> projects) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      projects.map((project) => project.encode()).toList(),
    );
  }
}
