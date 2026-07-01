import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:serious_python/serious_python.dart';

class YtDlpService {
  static Future<void>? _pythonStartup;

  Future<String> downloadAudio({
    required String url,
    required String role,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('有効なURLを入力してください。');
    }
    if (Platform.isIOS) {
      return _downloadOnIos(uri: uri, role: role);
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('このビルドにyt-dlp実行環境が含まれていません。');
    }

    final documents = await getApplicationDocumentsDirectory();
    final inputDirectory = Directory(path.join(documents.path, 'inputs'));
    await inputDirectory.create(recursive: true);
    final outputTemplate = path.join(
      inputDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}_${role}_%(id)s.%(ext)s',
    );
    final process = await Process.run(
      'python',
      [
        '-m',
        'yt_dlp',
        '--no-playlist',
        '--newline',
        '--force-overwrites',
        '--js-runtimes',
        'node',
        '--extract-audio',
        '--audio-format',
        'wav',
        '--audio-quality',
        '0',
        '--output',
        outputTemplate,
        '--print',
        'after_move:MR_OUTPUT:%(filepath)s',
        uri.toString(),
      ],
      environment: {
        ...Platform.environment,
        'PYTHONUTF8': '1',
        'PYTHONIOENCODING': 'utf-8',
      },
      stdoutEncoding: const Utf8Codec(allowMalformed: true),
      stderrEncoding: const Utf8Codec(allowMalformed: true),
      runInShell: true,
    );
    final stdout = process.stdout as String;
    final stderr = process.stderr as String;
    if (process.exitCode != 0) {
      final details = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
      throw Exception(_lastUsefulLine(details));
    }
    final outputLine = stdout
        .split(RegExp(r'\r?\n'))
        .lastWhere((line) => line.startsWith('MR_OUTPUT:'), orElse: () => '');
    if (outputLine.isEmpty) {
      throw Exception('yt-dlpは完了しましたが、出力ファイルを特定できませんでした。');
    }
    final outputPath = outputLine.substring('MR_OUTPUT:'.length).trim();
    if (!await File(outputPath).exists()) {
      throw Exception('ダウンロードした音声ファイルが見つかりません。');
    }
    return outputPath;
  }

  Future<String> _downloadOnIos({
    required Uri uri,
    required String role,
  }) async {
    await _ensurePythonBackend();
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:8765/download'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'url': uri.toString(), 'role': role}));
      final response = await request.close();
      final payload =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
      if (response.statusCode != HttpStatus.ok) {
        throw Exception(payload['error'] ?? 'yt-dlpの実行に失敗しました。');
      }
      final outputPath = payload['path'];
      if (outputPath is! String || !await File(outputPath).exists()) {
        throw Exception('ダウンロードした音声ファイルが見つかりません。');
      }
      return outputPath;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _ensurePythonBackend() {
    return _pythonStartup ??= _startAndWaitForPython();
  }

  Future<void> _startAndWaitForPython() async {
    SeriousPython.run();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:8765/health'),
        );
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode == HttpStatus.ok) return;
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } finally {
        client.close(force: true);
      }
    }
    _pythonStartup = null;
    throw Exception('内蔵yt-dlpを起動できませんでした。');
  }

  String _lastUsefulLine(String message) {
    final lines =
        message
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    return lines.isEmpty ? 'yt-dlpの実行に失敗しました。' : lines.last;
  }
}
