import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

class WavAudioProcessor {
  static Future<(String, double)> extract({
    required String originalPath,
    required String instrumentalPath,
    required double reduction,
  }) async {
    final result = await Isolate.run(
      () => _process(<String, Object>{
        'originalPath': originalPath,
        'instrumentalPath': instrumentalPath,
        'reduction': reduction,
      }),
    );
    return (
      result['outputPath']! as String,
      result['offsetSeconds']! as double,
    );
  }
}

Map<String, Object> _process(Map<String, Object> arguments) {
  final originalPath = arguments['originalPath']! as String;
  final instrumentalPath = arguments['instrumentalPath']! as String;
  final reduction = arguments['reduction']! as double;
  final original = _WavAudio.read(originalPath).normalized();
  final instrumental = _WavAudio.read(instrumentalPath).normalized();
  if (original.sampleRate != instrumental.sampleRate) {
    throw const FormatException('2つの音源のサンプルレートが異なります。');
  }

  final alignment = _findAlignment(
    original.samples,
    instrumental.samples,
    original.sampleRate,
  );
  final length = math.min(
    original.samples.length - alignment.$1,
    instrumental.samples.length - alignment.$2,
  );
  if (length <= 0) throw const FormatException('重なる音声区間がありません。');

  final output = _spectralSubtract(
    original: original.samples,
    instrumental: instrumental.samples,
    originalStart: alignment.$1,
    instrumentalStart: alignment.$2,
    length: length,
    reduction: reduction,
  );
  final outputDirectory = Directory(
    '${File(originalPath).parent.parent.path}${Platform.pathSeparator}outputs',
  )..createSync(recursive: true);
  final outputPath =
      '${outputDirectory.path}${Platform.pathSeparator}vocals_${DateTime.now().millisecondsSinceEpoch}.wav';
  _writePcm16Wav(
    outputPath,
    output.samples,
    original.sampleRate,
    start: output.start,
    length: length,
  );
  return <String, Object>{
    'outputPath': outputPath,
    'offsetSeconds': (alignment.$1 - alignment.$2) / original.sampleRate,
  };
}

({Float32List samples, int start}) _spectralSubtract({
  required Float32List original,
  required Float32List instrumental,
  required int originalStart,
  required int instrumentalStart,
  required int length,
  required double reduction,
}) {
  const fftSize = 2048;
  const hopSize = 512;
  const padding = fftSize ~/ 2;
  final paddedLength = length + padding * 2;
  final output = Float32List(paddedLength + fftSize);
  final weights = Float32List(paddedLength + fftSize);
  final window = Float64List(fftSize);
  for (var index = 0; index < fftSize; index++) {
    // Periodic Hann window, matching librosa's default STFT window.
    window[index] = 0.5 - 0.5 * math.cos(2 * math.pi * index / fftSize);
  }
  final fft = FFT(fftSize);
  final originalFrame = Float64List(fftSize);
  final instrumentalFrame = Float64List(fftSize);

  for (var frameStart = 0; frameStart < paddedLength; frameStart += hopSize) {
    for (var index = 0; index < fftSize; index++) {
      final sourceIndex = frameStart + index - padding;
      if (sourceIndex >= 0 && sourceIndex < length) {
        originalFrame[index] =
            original[originalStart + sourceIndex] * window[index];
        instrumentalFrame[index] =
            instrumental[instrumentalStart + sourceIndex] * window[index];
      } else {
        originalFrame[index] = 0;
        instrumentalFrame[index] = 0;
      }
    }

    final originalSpectrum = fft.realFft(originalFrame);
    final instrumentalSpectrum = fft.realFft(instrumentalFrame);
    for (var bin = 0; bin < fftSize; bin++) {
      final originalValue = originalSpectrum[bin];
      final instrumentalValue = instrumentalSpectrum[bin];
      final originalMagnitude = math.sqrt(
        originalValue.x * originalValue.x + originalValue.y * originalValue.y,
      );
      final instrumentalMagnitude = math.sqrt(
        instrumentalValue.x * instrumentalValue.x +
            instrumentalValue.y * instrumentalValue.y,
      );
      final vocalMagnitude = math.max(
        originalMagnitude - instrumentalMagnitude * reduction,
        0,
      );
      final magnitudeRatio =
          originalMagnitude > 1e-12 ? vocalMagnitude / originalMagnitude : 0.0;
      originalSpectrum[bin] = Float64x2(
        originalValue.x * magnitudeRatio,
        originalValue.y * magnitudeRatio,
      );
    }

    final reconstructed = fft.realInverseFft(originalSpectrum);
    for (var index = 0; index < fftSize; index++) {
      final target = frameStart + index;
      if (target >= output.length) break;
      final windowValue = window[index];
      output[target] += reconstructed[index] * windowValue;
      weights[target] += windowValue * windowValue;
    }
  }

  for (var index = 0; index < output.length; index++) {
    if (weights[index] > 1e-10) output[index] /= weights[index];
  }
  return (samples: output, start: padding);
}

(int, int) _findAlignment(
  Float32List original,
  Float32List instrumental,
  int sampleRate,
) {
  // FFT cross-correlation at about 1 kHz gives a robust millisecond estimate.
  final decimation = math.max(sampleRate ~/ 1000, 1);
  final analysisSamples = math.min(
    math.min(original.length, instrumental.length),
    sampleRate * 120,
  );
  final first = _downsample(original, analysisSamples, decimation);
  final second = _downsample(instrumental, analysisSamples, decimation);
  final reversedSecond = Float64List.fromList(second.reversed.toList());
  final correlation = convolution(first, reversedSecond);
  final maximumLag = math.min(30 * sampleRate ~/ decimation, first.length - 1);
  var bestIndex = second.length - 1;
  var bestValue = double.negativeInfinity;
  for (var lag = -maximumLag; lag <= maximumLag; lag++) {
    final index = lag + second.length - 1;
    if (index >= 0 &&
        index < correlation.length &&
        correlation[index] > bestValue) {
      bestValue = correlation[index];
      bestIndex = index;
    }
  }
  final coarseLag = (bestIndex - (second.length - 1)) * decimation;

  // Refine around the FFT estimate at exact sample resolution.
  final radius = decimation * 2;
  var bestLag = coarseLag;
  var bestScore = double.negativeInfinity;
  for (var lag = coarseLag - radius; lag <= coarseLag + radius; lag++) {
    final score = _normalizedCorrelationAtLag(
      original,
      instrumental,
      lag,
      math.min(sampleRate * 4, analysisSamples),
    );
    if (score > bestScore) {
      bestScore = score;
      bestLag = lag;
    }
  }
  return (math.max(0, bestLag), math.max(0, -bestLag));
}

Float64List _downsample(Float32List input, int sampleCount, int factor) {
  final output = Float64List((sampleCount + factor - 1) ~/ factor);
  var mean = 0.0;
  for (var outputIndex = 0; outputIndex < output.length; outputIndex++) {
    final start = outputIndex * factor;
    final end = math.min(start + factor, sampleCount);
    var sum = 0.0;
    for (var index = start; index < end; index++) {
      sum += input[index];
    }
    output[outputIndex] = sum / (end - start);
    mean += output[outputIndex];
  }
  mean /= output.length;
  for (var index = 0; index < output.length; index++) {
    output[index] -= mean;
  }
  return output;
}

double _normalizedCorrelationAtLag(
  Float32List first,
  Float32List second,
  int lag,
  int maximumSamples,
) {
  final firstStart = math.max(0, lag);
  final secondStart = math.max(0, -lag);
  final available = math.min(
    maximumSamples,
    math.min(first.length - firstStart, second.length - secondStart),
  );
  if (available <= 0) return double.negativeInfinity;
  var dot = 0.0;
  var firstEnergy = 0.0;
  var secondEnergy = 0.0;
  for (var index = 0; index < available; index++) {
    final a = first[firstStart + index];
    final b = second[secondStart + index];
    dot += a * b;
    firstEnergy += a * a;
    secondEnergy += b * b;
  }
  final denominator = math.sqrt(firstEnergy * secondEnergy);
  return denominator > 0 ? dot / denominator : double.negativeInfinity;
}

class _WavAudio {
  const _WavAudio(this.samples, this.sampleRate);

  final Float32List samples;
  final int sampleRate;

  _WavAudio normalized() {
    var peak = 0.0;
    for (final sample in samples) {
      peak = math.max(peak, sample.abs());
    }
    if (peak <= 1e-12) throw const FormatException('無音の音源は処理できません。');
    final normalized = Float32List(samples.length);
    for (var index = 0; index < samples.length; index++) {
      normalized[index] = samples[index] / peak;
    }
    return _WavAudio(normalized, sampleRate);
  }

  static _WavAudio read(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('WAVファイルとして読み込めませんでした。');
    }
    final data = ByteData.sublistView(bytes);
    var offset = 12;
    int? format;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;
    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, 4);
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      final content = offset + 8;
      if (content + chunkLength > bytes.length) break;
      if (chunkId == 'fmt ' && chunkLength >= 16) {
        format = data.getUint16(content, Endian.little);
        channels = data.getUint16(content + 2, Endian.little);
        sampleRate = data.getUint32(content + 4, Endian.little);
        bitsPerSample = data.getUint16(content + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = content;
        dataLength = chunkLength;
      }
      offset = content + chunkLength + (chunkLength.isOdd ? 1 : 0);
    }
    if (format == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataLength == null ||
        channels <= 0) {
      throw const FormatException('WAVの音声情報を読み取れませんでした。');
    }
    final bytesPerSample = bitsPerSample ~/ 8;
    final frameSize = bytesPerSample * channels;
    if (frameSize <= 0 || (format != 1 && format != 3)) {
      throw const FormatException('対応していないWAV形式です。');
    }
    final frameCount = dataLength ~/ frameSize;
    final samples = Float32List(frameCount);
    for (var frame = 0; frame < frameCount; frame++) {
      var mono = 0.0;
      for (var channel = 0; channel < channels; channel++) {
        final sampleOffset =
            dataOffset + frame * frameSize + channel * bytesPerSample;
        mono += _readSample(data, sampleOffset, format, bitsPerSample);
      }
      samples[frame] = mono / channels;
    }
    return _WavAudio(samples, sampleRate);
  }
}

double _readSample(ByteData data, int offset, int format, int bits) {
  if (format == 3 && bits == 32) return data.getFloat32(offset, Endian.little);
  if (format == 3 && bits == 64) return data.getFloat64(offset, Endian.little);
  if (format != 1) throw const FormatException('対応していないFloat WAVです。');
  switch (bits) {
    case 8:
      return (data.getUint8(offset) - 128) / 128;
    case 16:
      return data.getInt16(offset, Endian.little) / 32768;
    case 24:
      var value =
          data.getUint8(offset) |
          (data.getUint8(offset + 1) << 8) |
          (data.getUint8(offset + 2) << 16);
      if ((value & 0x800000) != 0) value |= ~0xFFFFFF;
      return value / 8388608;
    case 32:
      return data.getInt32(offset, Endian.little) / 2147483648;
    default:
      throw FormatException('対応していないPCMビット深度です: $bits bit');
  }
}

void _writePcm16Wav(
  String path,
  Float32List samples,
  int sampleRate, {
  required int start,
  required int length,
}) {
  const channels = 1;
  const bits = 16;
  const bytesPerSample = bits ~/ 8;
  final dataLength = length * bytesPerSample;
  final output = ByteData(44 + dataLength);
  _putAscii(output, 0, 'RIFF');
  output.setUint32(4, 36 + dataLength, Endian.little);
  _putAscii(output, 8, 'WAVE');
  _putAscii(output, 12, 'fmt ');
  output.setUint32(16, 16, Endian.little);
  output.setUint16(20, 1, Endian.little);
  output.setUint16(22, channels, Endian.little);
  output.setUint32(24, sampleRate, Endian.little);
  output.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  output.setUint16(32, channels * bytesPerSample, Endian.little);
  output.setUint16(34, bits, Endian.little);
  _putAscii(output, 36, 'data');
  output.setUint32(40, dataLength, Endian.little);

  var peak = 0.0;
  for (var index = 0; index < length; index++) {
    peak = math.max(peak, samples[start + index].abs());
  }
  final gain = peak > 1e-12 ? 0.98 / peak : 1.0;
  for (var index = 0; index < length; index++) {
    final value = (samples[start + index] * gain).clamp(-1.0, 1.0);
    output.setInt16(44 + index * 2, (value * 32767).round(), Endian.little);
  }
  File(path).writeAsBytesSync(output.buffer.asUint8List(), flush: true);
}

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

void _putAscii(ByteData data, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    data.setUint8(offset + index, value.codeUnitAt(index));
  }
}
