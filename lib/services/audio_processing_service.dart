import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'wav_audio_processor.dart';

class ExtractionResult {
  const ExtractionResult({
    required this.outputPath,
    required this.offsetSeconds,
  });

  final String outputPath;
  final double offsetSeconds;
}

class AudioProcessingService {
  static const _channel = MethodChannel('com.takeshi.mr_remover/audio');

  Future<ExtractionResult> extract({
    required String originalPath,
    required String instrumentalPath,
    required double reduction,
  }) async {
    var preparedOriginal = originalPath;
    var preparedInstrumental = instrumentalPath;
    if (!_isWav(preparedOriginal) || !_isWav(preparedInstrumental)) {
      if (!Platform.isIOS) {
        throw const FormatException('この環境ではWAVファイルを選択してください。');
      }
      preparedOriginal = await _prepareWav(preparedOriginal);
      preparedInstrumental = await _prepareWav(preparedInstrumental);
    }
    final result = await WavAudioProcessor.extract(
      originalPath: preparedOriginal,
      instrumentalPath: preparedInstrumental,
      reduction: reduction,
    );
    return ExtractionResult(outputPath: result.$1, offsetSeconds: result.$2);
  }

  bool _isWav(String filePath) =>
      path.extension(filePath).toLowerCase() == '.wav';

  Future<String> _prepareWav(String filePath) async {
    if (_isWav(filePath)) return filePath;
    final result = await _channel.invokeMethod<String>('prepareWav', {
      'path': filePath,
    });
    if (result == null) {
      throw PlatformException(
        code: 'DECODE_FAILED',
        message: 'WAVへの変換に失敗しました。',
      );
    }
    return result;
  }
}
