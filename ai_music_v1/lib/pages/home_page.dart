import 'package:flutter/material.dart';
import 'package:ai_music_v1/services/audio_service.dart';
import 'package:ai_music_v1/services/pitch_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'records_page.dart';
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
  
  bool isRecording = false;
  bool isAnalyzing = false;
  String resultText = "点击麦克风按钮开始录一段声音";

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Violin Teacher"),
        actions: [
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Notes Selection
            Wrap(
              spacing: 8.0,
              children: _aMajorScale.map((note) {
                bool isSelected = _pitchService.targetNoteName == note["name"];
                return ChoiceChip(
                  label: Text(note["name"]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected && !isRecording && !isAnalyzing) {
                      setState(() {
                        _pitchService.setTargetNote(
                          note["name"], 
                          note["midi"], 
                          note["freq"]
                        );
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            
            // Result Display
            Expanded(
              child: Center(
                child: isAnalyzing
                    ? const CircularProgressIndicator() // 正在分析时转圈圈
                    : SingleChildScrollView(
                        child: Text(
                          resultText,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (isAnalyzing) return; // 正在分析时不让点

          var status = await Permission.microphone.status;
          if (status.isGranted) {
            if (isRecording) {
              // 停止录音并开始分析
              setState(() {
                isRecording = false;
                isAnalyzing = true;
                resultText = "正在解析录音文件并进行算法比对...\n大概需要几秒钟，请稍候";
              });
              
              String? filePath = await _audioService.stopRecording();
              
              if (filePath != null) {
                String report = await _pitchService.analyzeAudioFileWithSegmentation(filePath);
                
                // 将录音持久化保存到数据库中
                final newRecord = RecordEntry(
                  date: DateTime.now().toString(),
                  filePath: filePath,
                  comment: report,
                );
                await DatabaseHelper.instance.insertRecord(newRecord);

                setState(() {
                  resultText = report;
                  isAnalyzing = false;
                });
              } else {
                setState(() {
                  resultText = "录音保存失败！";
                  isAnalyzing = false;
                });
              }
              
            } else {
              // 开始录音
              bool success = await _audioService.startRecording();
              if (success) {
                setState(() {
                  isRecording = true;
                  resultText = "🔴 正在录音中...\n按停止键结束并获得检测报告。\n系统目前锁定的检测目标是 ${_pitchService.targetNoteName}。";
                });
              } else {
                setState(() {
                  resultText = "⚠️ 麦克风引擎启动失败！请杀掉App或检查设置中的麦克风权限后重试。";
                });
              }
            }
          } else {
            _requestMicrophonePermission();
          }
        },
        backgroundColor: isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
        child: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
