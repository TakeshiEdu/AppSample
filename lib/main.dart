import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(linux: false, windows: true);
  }
  runApp(const MrRemoverApp());
}

class MrRemoverApp extends StatelessWidget {
  const MrRemoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6D5EF7);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MR Remover',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF171821),
        ),
        scaffoldBackgroundColor: const Color(0xFF101118),
        useMaterial3: true,
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.always,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
