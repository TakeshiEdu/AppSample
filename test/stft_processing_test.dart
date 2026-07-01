import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_remover/services/wav_audio_processor.dart';

void main() {
  test('STFT extraction suppresses the instrumental frequency', () async {
    const sampleRate = 8000;
    const seconds = 3;
    final root = await Directory.systemTemp.createTemp('mr_remover_stft_');
    final inputs = Directory('${root.path}${Platform.pathSeparator}inputs')
      ..createSync();
    final originalPath = '${inputs.path}${Platform.pathSeparator}original.wav';
    final instrumentalPath =
        '${inputs.path}${Platform.pathSeparator}instrumental.wav';
    final original = Float64List(sampleRate * seconds);
    final instrumental = Float64List(sampleRate * seconds);
    for (var index = 0; index < original.length; index++) {
      final time = index / sampleRate;
      final backing = .45 * math.sin(2 * math.pi * 440 * time);
      final vocal = .3 * math.sin(2 * math.pi * 880 * time);
      instrumental[index] = backing;
      original[index] = backing + vocal;
    }
    _writeWav(originalPath, original, sampleRate);
    _writeWav(instrumentalPath, instrumental, sampleRate);

    final result = await WavAudioProcessor.extract(
      originalPath: originalPath,
      instrumentalPath: instrumentalPath,
      reduction: .65,
    );
    final extracted = _readPcm16(result.$1);
    final backingLevel = _frequencyLevel(extracted, sampleRate, 440);
    final vocalLevel = _frequencyLevel(extracted, sampleRate, 880);

    expect(File(result.$1).existsSync(), isTrue);
    expect(extracted.length, original.length);
    expect(vocalLevel, greaterThan(backingLevel * 2));
    await root.delete(recursive: true);
  });
}

double _frequencyLevel(List<double> samples, int sampleRate, double frequency) {
  var real = 0.0;
  var imaginary = 0.0;
  for (var index = 0; index < samples.length; index++) {
    final phase = 2 * math.pi * frequency * index / sampleRate;
    real += samples[index] * math.cos(phase);
    imaginary -= samples[index] * math.sin(phase);
  }
  return math.sqrt(real * real + imaginary * imaginary) / samples.length;
}

void _writeWav(String path, List<double> samples, int sampleRate) {
  final data = ByteData(44 + samples.length * 2);
  _ascii(data, 0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  _ascii(data, 8, 'WAVE');
  _ascii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _ascii(data, 36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var index = 0; index < samples.length; index++) {
    data.setInt16(
      44 + index * 2,
      (samples[index].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}

List<double> _readPcm16(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return List<double>.generate(
    (bytes.length - 44) ~/ 2,
    (index) => data.getInt16(44 + index * 2, Endian.little) / 32768,
  );
}

void _ascii(ByteData data, int offset, String text) {
  for (var index = 0; index < text.length; index++) {
    data.setUint8(offset + index, text.codeUnitAt(index));
  }
}
