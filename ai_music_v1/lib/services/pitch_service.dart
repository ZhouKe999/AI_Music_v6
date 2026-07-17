import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/yin.dart';

class PitchService {
  static const String _analysisEndpoint = 'http://10.0.2.2:8000/analyze';
  static const int _frameSize = 2048;
  static const int _hopSize = 512;
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const List<int> _aMajorMidi = [69, 71, 73, 74, 76, 78, 80, 81];
  static const List<String> _aMajorNames = [
    'A4',
    'B4',
    'C#5',
    'D5',
    'E5',
    'F#5',
    'G#5',
    'A5',
  ];

  final int sampleRate = 44100;
  
  // Python script parameters
  // 调整这里的 rmsThreshold（能量阈值）可以控制收音灵敏度
  // 因为底噪问题，先调回稍微高一点的值，避免纯噪音被当做信号
  final double rmsThreshold = 0.0001; 
  final double freqJumpThreshold = 50.0;
  
  // Target variables
  String targetNoteName = "B4";
  double targetMidi = 71.0; 
  double targetFreq = 493.88; 
  final double errorCents = 15.0;

  void setTargetNote(String noteName, double midi, double freq) {
    targetNoteName = noteName;
    targetMidi = midi;
    targetFreq = freq;
  }

  double hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 12.0 * (log(hz / 440.0) / ln2) + 69.0;
  }

  Future<List<double>> decodeWavToFloatBuffer(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const PitchAnalysisException('找不到录音文件。');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 44) {
      throw const PitchAnalysisException('录音文件为空或不是有效的 WAV 文件。');
    }

    final byteData = ByteData.sublistView(bytes);
    var chunkOffset = 12;
    int? dataOffset;
    int? dataLength;

    while (chunkOffset + 8 <= bytes.length) {
      final chunkSize = byteData.getUint32(chunkOffset + 4, Endian.little);
      final chunkDataOffset = chunkOffset + 8;
      if (chunkDataOffset + chunkSize > bytes.length) {
        throw const PitchAnalysisException('WAV 文件的数据块不完整。');
      }

      if (bytes[chunkOffset] == 100 &&
          bytes[chunkOffset + 1] == 97 &&
          bytes[chunkOffset + 2] == 116 &&
          bytes[chunkOffset + 3] == 97) {
        dataOffset = chunkDataOffset;
        dataLength = chunkSize;
        break;
      }

      chunkOffset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataOffset == null || dataLength == null) {
      throw const PitchAnalysisException('WAV 文件中找不到 PCM 数据。');
    }

    final dataEnd = dataOffset + dataLength;
    final floatBuffer = <double>[];
    for (var offset = dataOffset; offset + 1 < dataEnd; offset += 2) {
      final pcm16 = byteData.getInt16(offset, Endian.little);
      floatBuffer.add(pcm16 / 32768.0);
    }

    return floatBuffer;
  }

  double? detectPitchFromSamples(List<double> samples) {
    if (samples.length < _frameSize) {
      return null;
    }

    final yin = Yin(sampleRate, _frameSize);
    final validPitches = <double>[];

    for (var offset = 0; offset <= samples.length - _frameSize; offset += _hopSize) {
      final frame = samples.sublist(offset, offset + _frameSize);
      var rms = 0.0;
      for (final value in frame) {
        rms += value * value;
      }

      final pitch = yin.getPitch(frame);
      if (sqrt(rms / _frameSize) >= rmsThreshold && pitch > 0) {
        validPitches.add(pitch);
      }
    }

    if (validPitches.isEmpty) {
      return null;
    }

    validPitches.sort();
    return validPitches[validPitches.length ~/ 2];
  }

  Future<String> analyzeAudioFile(String filePath) async {
    final report = StringBuffer();
    report.writeln("--- Pitch Analysis Report ---");
    report.writeln("Target Note: $targetNoteName ($targetFreq Hz)\n");

    try {
      final detectedFrequency = detectPitchFromSamples(
        await decodeWavToFloatBuffer(filePath),
      );
      if (detectedFrequency == null) {
        report.writeln("No valid pitch detected. Check if audio is too quiet or noisy.");
        return report.toString();
      }

      final midi = hzToMidi(detectedFrequency);
      final centsDiff = (midi - targetMidi) * 100;
      final status = centsDiff > errorCents
          ? "Too Sharp (High)"
          : centsDiff < -errorCents
              ? "Too Flat (Low)"
              : "Accurate";

      report.writeln("Detected Frequency: ${detectedFrequency.toStringAsFixed(2)} Hz");
      report.writeln("Difference: ${centsDiff > 0 ? '+' : ''}${centsDiff.toStringAsFixed(1)} cents\n");
      report.writeln("Result: $status");
    } on PitchAnalysisException catch (error) {
      report.writeln(error.message);
    }

    return report.toString();
  }

  Future<String> analyzeAudioFileWithSegmentation(String filePath) async {
    try {
      final noteEvents = await _fetchNoteEvents(filePath);
      noteEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      if (noteEvents.length != _aMajorMidi.length) {
        return '检测到 ${noteEvents.length} 个音符，期望 8 个。可能存在漏拉、多拉或分割错误，本次暂不生成音准报告。';
      }

      final floatBuffer = await decodeWavToFloatBuffer(filePath);
      final report = StringBuffer()
        ..writeln('--- A Major Scale Pitch Analysis ---')
        ..writeln('Basic Pitch 已识别 8 个音符，以下为 YIN 音准分析：\n');

      for (var index = 0; index < noteEvents.length; index++) {
        final event = noteEvents[index];
        final startSample = (event.startTime * sampleRate)
            .floor()
            .clamp(0, floatBuffer.length)
            .toInt();
        final endSample = (event.endTime * sampleRate)
            .ceil()
            .clamp(0, floatBuffer.length)
            .toInt();
        final targetMidi = _aMajorMidi[index];
        final targetFrequency = 440.0 * pow(2, (targetMidi - 69) / 12);

        report.writeln(
          '${index + 1}. ${_aMajorNames[index]} '
          '(${event.startTime.toStringAsFixed(2)}-${event.endTime.toStringAsFixed(2)} s)',
        );

        if (endSample <= startSample || endSample - startSample < _frameSize) {
          report.writeln('   状态: insufficient_samples（片段过短，无法检测）\n');
          continue;
        }

        final detectedFrequency = detectPitchFromSamples(
          floatBuffer.sublist(startSample, endSample),
        );
        if (detectedFrequency == null) {
          report.writeln('   状态: no_pitch_detected（没有检测到稳定音高）\n');
          continue;
        }

        final centsDeviation =
            1200 * (log(detectedFrequency / targetFrequency) / ln2);
        final status = centsDeviation.abs() <= errorCents
            ? 'Accurate'
            : centsDeviation > 0
                ? 'Too Sharp'
                : 'Too Flat';
        report.writeln('   检测频率: ${detectedFrequency.toStringAsFixed(2)} Hz');
        report.writeln('   音分偏差: ${centsDeviation.toStringAsFixed(1)} cents');
        report.writeln('   状态: ok ($status)\n');
      }

      return report.toString();
    } on TimeoutException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return '音频分析请求超时，请确认后端服务正在运行后重试。';
    } on SocketException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return '无法连接音频分析服务，请确认后端已启动并可通过 10.0.2.2:8000 访问。';
    } on http.ClientException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return '音频分析网络错误：${error.message}';
    } on PitchAnalysisException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return error.message;
    } on FormatException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return '音频分析服务返回了无法识别的数据。';
    } catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return '音频分析失败：$error (${error.runtimeType})';
    }
  }

  void _logAnalysisError(Object error, StackTrace stackTrace) {
    print('音频分析失败，异常详情: $error');
    print('异常类型: ${error.runtimeType}');
    print('堆栈信息: $stackTrace');
  }

  Future<List<_NoteEvent>> _fetchNoteEvents(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse(_analysisEndpoint));
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: 'violin_record.wav',
      ),
    );

    final response = await request.send().timeout(_requestTimeout);
    final responseBody = await response.stream.bytesToString();
    print('Basic Pitch HTTP 状态码: ${response.statusCode}');
    print('Basic Pitch HTTP 响应体: $responseBody');
    final decoded = jsonDecode(responseBody);

    if (response.statusCode != 200) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw PitchAnalysisException(detail?.toString() ?? '服务返回 HTTP ${response.statusCode}。');
    }

    if (decoded is! Map<String, dynamic> || decoded['note_events'] is! List) {
      throw const FormatException('Missing note_events');
    }

    return (decoded['note_events'] as List).map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid note event');
      }
      return _NoteEvent(
        startTime: (value['start_time'] as num).toDouble(),
        endTime: (value['end_time'] as num).toDouble(),
      );
    }).toList();
  }
}

class _NoteEvent {
  const _NoteEvent({required this.startTime, required this.endTime});

  final double startTime;
  final double endTime;
}

class PitchAnalysisException implements Exception {
  const PitchAnalysisException(this.message);

  final String message;

  @override
  String toString() => 'PitchAnalysisException: $message';
}
