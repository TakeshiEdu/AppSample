import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/task_controller.dart';
import 'screens/home_screen.dart';
import 'services/task_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleTaskerApp());
}

class SimpleTaskerApp extends StatelessWidget {
  const SimpleTaskerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) =>
              TaskController(SharedPreferencesTaskStorageService())
                ..loadTasks(),
      child: MaterialApp(
        title: 'SimpleTasker',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff4f46e5),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
