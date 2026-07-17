import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  
  // 保存录音的本地绝对路径
  String? recordedFilePath;

  Future<void> init() async {
    // record package 默认自己处理初始化，只需要看有没有权限即可
  }

  /// 开始录音，保存到本地文件
  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        // 获取手机的临时文件夹路径
        Directory tempDir = await getTemporaryDirectory();
        recordedFilePath = '${tempDir.path}/violin_record.wav';

        // 使用真正的 WAV 容器，Basic Pitch 无法解析只有 PCM 样本的 .wav 文件。
        final recordConfig = const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        );

        await _recorder.start(
          recordConfig,
          path: recordedFilePath!,
        );

        print("DEBUG: 录音开始，文件将保存在: $recordedFilePath");
        return true;
      } else {
        print("DEBUG ERROR: 没有麦克风权限");
        return false;
      }
    } catch (e) {
      print("DEBUG ERROR: 录音启动失败 - $e");
      return false;
    }
  }

  /// 停止录音，并返回保存的文件路径
  Future<String?> stopRecording() async {
    if (await _recorder.isRecording()) {
      String? path = await _recorder.stop();
      if (path != null) {
        recordedFilePath = path;
      }
      print("DEBUG: 录音结束，文件已保存至: $recordedFilePath");
      return recordedFilePath;
    }
    return null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
