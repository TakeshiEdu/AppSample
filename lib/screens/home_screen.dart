import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;

import '../models/extraction_project.dart';
import '../services/audio_processing_service.dart';
import '../services/media_import_service.dart';
import '../services/project_repository.dart';
import '../services/yt_dlp_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _importer = MediaImportService();
  final _processor = AudioProcessingService();
  final _repository = ProjectRepository();
  final _downloader = YtDlpService();
  final _player = AudioPlayer();
  final _originalUrlController = TextEditingController();
  final _instrumentalUrlController = TextEditingController();

  String? _originalPath;
  String? _instrumentalPath;
  String? _outputPath;
  String? _loadedPlaybackPath;
  double _reduction = 1;
  bool _processing = false;
  bool _downloadingOriginal = false;
  bool _downloadingInstrumental = false;
  String _status = '2つの音源を選んでください';
  List<ExtractionProject> _projects = const [];

  bool get _canExtract =>
      _originalPath != null && _instrumentalPath != null && !_processing;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _repository.load();
    if (mounted) setState(() => _projects = projects);
  }

  Future<void> _pickOriginal() => _pick(role: 'original', original: true);

  Future<void> _pickInstrumental() =>
      _pick(role: 'instrumental', original: false);

  Future<void> _pick({required String role, required bool original}) async {
    final selected = await _importer.pickAndCopy(role: role);
    if (selected == null || !mounted) return;
    setState(() {
      if (original) {
        _originalPath = selected;
      } else {
        _instrumentalPath = selected;
      }
      _outputPath = null;
      _status = '準備できました';
    });
  }

  Future<void> _download({required bool original}) async {
    final controller =
        original ? _originalUrlController : _instrumentalUrlController;
    if (controller.text.trim().isEmpty) {
      setState(() => _status = 'URLを入力してください');
      return;
    }
    setState(() {
      if (original) {
        _downloadingOriginal = true;
      } else {
        _downloadingInstrumental = true;
      }
      _status = original ? '原曲をダウンロードしています…' : 'インスト音源をダウンロードしています…';
    });
    try {
      final downloaded = await _downloader.downloadAudio(
        url: controller.text,
        role: original ? 'original' : 'instrumental',
      );
      if (!mounted) return;
      setState(() {
        if (original) {
          _originalPath = downloaded;
        } else {
          _instrumentalPath = downloaded;
        }
        _outputPath = null;
        _status = original ? '原曲をダウンロードしました' : 'インスト音源をダウンロードしました';
      });
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'ダウンロードできませんでした: $error');
    } finally {
      if (mounted) {
        setState(() {
          if (original) {
            _downloadingOriginal = false;
          } else {
            _downloadingInstrumental = false;
          }
        });
      }
    }
  }

  Future<void> _extract() async {
    if (!_canExtract) return;
    await _player.stop();
    setState(() {
      _processing = true;
      _status = '位置を合わせてMRを除去しています…';
    });
    try {
      final result = await _processor.extract(
        originalPath: _originalPath!,
        instrumentalPath: _instrumentalPath!,
        reduction: _reduction,
      );
      final now = DateTime.now();
      final project = ExtractionProject(
        id: now.microsecondsSinceEpoch.toString(),
        name: path.basenameWithoutExtension(_originalPath!),
        createdAt: now,
        originalPath: _originalPath!,
        instrumentalPath: _instrumentalPath!,
        outputPath: result.outputPath,
        reduction: _reduction,
      );
      final projects = [project, ..._projects].take(20).toList();
      await _repository.save(projects);
      if (!mounted) return;
      setState(() {
        _outputPath = result.outputPath;
        _projects = projects;
        _status = '抽出完了（補正 ${result.offsetSeconds.toStringAsFixed(2)} 秒）';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _status = '処理できませんでした: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _togglePlayback(String filePath) async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_loadedPlaybackPath != filePath ||
        _player.processingState == ProcessingState.completed) {
      await _player.setFilePath(filePath);
      _loadedPlaybackPath = filePath;
    }
    unawaited(_player.play());
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openProject(ExtractionProject project) async {
    if (!File(project.outputPath).existsSync()) {
      setState(() => _status = '履歴の出力ファイルが見つかりません');
      return;
    }
    setState(() {
      _originalPath = project.originalPath;
      _instrumentalPath = project.instrumentalPath;
      _outputPath = project.outputPath;
      _reduction = project.reduction;
      _status = '履歴を開きました';
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _originalUrlController.dispose();
    _instrumentalUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MR REMOVER',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
          children: [
            Text(
              '音源から、歌声を取り出す。',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '原曲とインスト音源を端末内で比較します。',
              style: TextStyle(color: Colors.white.withValues(alpha: .62)),
            ),
            const SizedBox(height: 22),
            _downloadPanel(),
            const SizedBox(height: 18),
            _SourceCard(
              number: '01',
              title: '原曲',
              subtitle:
                  _originalPath == null
                      ? 'WAV / MP3 / M4A'
                      : path.basename(_originalPath!),
              selected: _originalPath != null,
              onTap: _pickOriginal,
            ),
            const SizedBox(height: 12),
            _SourceCard(
              number: '02',
              title: 'インスト音源',
              subtitle:
                  _instrumentalPath == null
                      ? '同じ曲の楽器のみ音源'
                      : path.basename(_instrumentalPath!),
              selected: _instrumentalPath != null,
              onTap: _pickInstrumental,
            ),
            const SizedBox(height: 18),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '除去の強さ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _reduction.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Color(0xFFA99FFF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _reduction,
                    min: 0,
                    max: 2,
                    divisions: 40,
                    label: _reduction.toStringAsFixed(2),
                    onChanged:
                        _processing
                            ? null
                            : (value) => setState(() => _reduction = value),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _canExtract ? _extract : null,
                      icon:
                          _processing
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.auto_awesome),
                      label: Text(_processing ? '処理中…' : 'ボーカルを抽出'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: .65),
                    ),
                  ),
                ],
              ),
            ),
            if (_outputPath != null) ...[
              const SizedBox(height: 18),
              _panel(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.graphic_eq),
                      ),
                      title: const Text(
                        '抽出結果',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(path.basename(_outputPath!)),
                    ),
                    StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;
                        return StreamBuilder<Duration>(
                          stream: _player.positionStream,
                          initialData: _player.position,
                          builder: (context, positionSnapshot) {
                            final rawPosition =
                                positionSnapshot.data ?? Duration.zero;
                            final position =
                                rawPosition > duration ? duration : rawPosition;
                            final maximum =
                                duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1.0;
                            return Column(
                              children: [
                                Slider(
                                  value:
                                      position.inMilliseconds
                                          .toDouble()
                                          .clamp(0.0, maximum)
                                          .toDouble(),
                                  max: maximum,
                                  onChanged:
                                      duration == Duration.zero
                                          ? null
                                          : (value) => _player.seek(
                                            Duration(
                                              milliseconds: value.round(),
                                            ),
                                          ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position)),
                                      Text(_formatDuration(duration)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      initialData: _player.playerState,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        final playing = state?.playing ?? false;
                        final completed =
                            state?.processingState == ProcessingState.completed;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              tooltip: '停止',
                              onPressed: _stopPlayback,
                              icon: const Icon(Icons.stop),
                            ),
                            const SizedBox(width: 14),
                            IconButton.filled(
                              tooltip: playing ? '一時停止' : '再生',
                              iconSize: 30,
                              onPressed: () => _togglePlayback(_outputPath!),
                              icon: Icon(
                                playing
                                    ? Icons.pause
                                    : completed
                                    ? Icons.replay
                                    : Icons.play_arrow,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近の抽出',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_projects.length} 件',
                  style: TextStyle(color: Colors.white.withValues(alpha: .55)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_projects.isEmpty)
              Text(
                'まだ履歴はありません',
                style: TextStyle(color: Colors.white.withValues(alpha: .5)),
              )
            else
              ..._projects
                  .take(5)
                  .map(
                    (project) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${project.createdAt.month}/${project.createdAt.day}  強さ ${project.reduction.toStringAsFixed(2)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openProject(project),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF191A24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }

  Widget _downloadPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'URLから音源を取得',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _urlInput(
            controller: _originalUrlController,
            label: '原曲URL',
            downloading: _downloadingOriginal,
            onDownload: () => _download(original: true),
          ),
          const SizedBox(height: 12),
          _urlInput(
            controller: _instrumentalUrlController,
            label: 'インスト音源URL',
            downloading: _downloadingInstrumental,
            onDownload: () => _download(original: false),
          ),
        ],
      ),
    );
  }

  Widget _urlInput({
    required TextEditingController controller,
    required String label,
    required bool downloading,
    required VoidCallback onDownload,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            enabled: !downloading,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'https://…',
              prefixIcon: const Icon(Icons.link),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: downloading ? null : onDownload,
          icon:
              downloading
                  ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.download),
          label: Text(downloading ? '取得中' : 'DL'),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF191A24),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF8E82FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                color: selected ? const Color(0xFF65D6A6) : Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
