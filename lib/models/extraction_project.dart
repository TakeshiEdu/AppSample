import 'dart:convert';

class ExtractionProject {
  const ExtractionProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.originalPath,
    required this.instrumentalPath,
    required this.outputPath,
    required this.reduction,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String originalPath;
  final String instrumentalPath;
  final String outputPath;
  final double reduction;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'originalPath': originalPath,
    'instrumentalPath': instrumentalPath,
    'outputPath': outputPath,
    'reduction': reduction,
  };

  factory ExtractionProject.fromJson(Map<String, dynamic> json) {
    return ExtractionProject(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      originalPath: json['originalPath'] as String,
      instrumentalPath: json['instrumentalPath'] as String,
      outputPath: json['outputPath'] as String,
      reduction: (json['reduction'] as num).toDouble(),
    );
  }

  String encode() => jsonEncode(toJson());
}
