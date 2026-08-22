import 'package:flutter/material.dart';
import 'package:ai_music_v1/services/audio_service.dart';
import 'package:ai_music_v1/services/pitch_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_music_v1/theme/app_theme.dart';
import 'package:ai_music_v1/widgets/scale_strip.dart';
import 'package:ai_music_v1/services/scale_demo_player.dart';
import 'records_page.dart';
import 'results_page.dart';
import 'fingering_reference_page.dart';
import '../models/record_entry.dart';
import '../services/database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioService _audioService = AudioService();
  final PitchService _pitchService = PitchService();
  final ScaleDemoPlayer _demoPlayer = ScaleDemoPlayer();

  bool isRecording = false;
  bool isAnalyzing = false;
  bool _isPlayingDemo = false;
  final Set<String> _selectedPracticeNotes = <String>{};

  // A Major Scale A4 to A5
  final List<Map<String, dynamic>> _aMajorScale = [
    {"name": "A4", "midi": 69.0, "freq": 440.00},
    {"name": "B4", "midi": 71.0, "freq": 493.88},
    {"name": "C#5", "midi": 73.0, "freq": 554.37},
    {"name": "D5", "midi": 74.0, "freq": 587.33},
    {"name": "E5", "midi": 76.0, "freq": 659.25},
    {"name": "F#5", "midi": 78.0, "freq": 739.99},
    {"name": "G#5", "midi": 80.0, "freq": 830.61},
    {"name": "A5", "midi": 81.0, "freq": 880.00},
  ];

  @override
  void initState() {
    super.initState();
    _requestMicrophonePermission();
  }

  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _demoPlayer.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _statusText {
    if (isRecording) {
      return _selectedPracticeNotes.isEmpty
          ? "正在录音中...\n请拉完整的A大调音阶。按停止键结束并获得检测报告。"
          : "正在录音中...\n请练习：${_selectedPracticeNotes.join('、')}。可按任意顺序重复演奏，按停止键结束并获得检测报告。";
    }
    if (isAnalyzing) {
      return "正在解析录音文件并进行算法比对...\n大概需要几秒钟，请稍候";
    }
    return "点击麦克风按钮开始录一段声音";
  }

  Future<void> _handleMicPressed() async {
    if (isAnalyzing) return;

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      _requestMicrophonePermission();
      return;
    }

    if (isRecording) {
      setState(() {
        isRecording = false;
        isAnalyzing = true;
      });

      String? filePath = await _audioService.stopRecording();

      if (filePath == null) {
        setState(() => isAnalyzing = false);
        _showMessage("录音保存失败！");
        return;
      }

      final practiceTargets = _aMajorScale
          .where((note) => _selectedPracticeNotes.contains(note["name"]))
          .map(
            (note) => PracticeTarget(
              noteName: note["name"] as String,
              midi: (note["midi"] as double).round(),
              frequency: note["freq"] as double,
            ),
          )
          .toList();

      final analysis = await _pitchService.analyzeAudioFileWithSegmentation(
        filePath,
        practiceTargets: practiceTargets,
      );
      final feedback = await _pitchService.generateFeedback(analysis);

      final newRecord = RecordEntry(
        date: DateTime.now().toString(),
        filePath: filePath,
        comment: analysis.report,
      );
      await DatabaseHelper.instance.insertRecord(newRecord);

      if (!mounted) return;
      setState(() => isAnalyzing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsPage(analysis: analysis, feedback: feedback),
        ),
      );
    } else {
      bool success = await _audioService.startRecording();
      if (success) {
        setState(() => isRecording = true);
      } else {
        _showMessage("麦克风引擎启动失败！请杀掉App或检查设置中的麦克风权限后重试。");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Violin Teacher"),
        actions: [
          IconButton(
            icon: const Icon(Icons.back_hand_outlined),
            tooltip: '指法参考',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FingeringReferencePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecordsPage()),
              );
            },
          ),
        ],
      ),
      // 换成可滚动容器：内容多了也不会溢出报错，而是自然滚动
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // 音阶示意条：录音前预览接下来要拉的完整A大调音阶
            ScaleStrip(
              noteLabels:
                  _aMajorScale.map((note) => note["name"] as String).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: (isRecording || isAnalyzing)
                    ? null
                    : () async {
                        if (_isPlayingDemo) {
                          _demoPlayer.stop();
                          setState(() => _isPlayingDemo = false);
                          return;
                        }
                        setState(() => _isPlayingDemo = true);
                        await _demoPlayer.playScale();
                        if (mounted) setState(() => _isPlayingDemo = false);
                      },
                icon: Icon(_isPlayingDemo ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlayingDemo ? "停止播放" : "播放完整音阶示范"),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 小提琴装饰图，现在是首页的视觉主体
            Center(
              child: Image.asset(
                'assets/images/B.png',
                height: 500,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 针对性练习目标：改成默认收起的折叠区，不常驻占空间
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                  ),
                  title: Text(
                    "针对性练习（可选，最多2个）",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _aMajorScale.map((note) {
                        final noteName = note["name"] as String;
                        final isSelected = _selectedPracticeNotes.contains(noteName);
                        return FilterChip(
                          label: Text(note["name"]),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (isRecording || isAnalyzing) return;
                            if (selected && _selectedPracticeNotes.length == 2) {
                              _showMessage("针对练习最多选择两个音。");
                              return;
                            }
                            setState(() {
                              if (selected) {
                                _selectedPracticeNotes.add(noteName);
                              } else {
                                _selectedPracticeNotes.remove(noteName);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 状态提示区：录音中 / 分析中 / 待机文案
            if (isAnalyzing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isAnalyzing ? null : _handleMicPressed,
        backgroundColor: isRecording ? AppColors.statusSharp : null,
        child: Icon(isRecording ? Icons.stop : Icons.mic),
      ),
    );
  }
}