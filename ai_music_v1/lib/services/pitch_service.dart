import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/yin.dart';

class SegmentedAnalysisResult {
  const SegmentedAnalysisResult({
    required this.report,
    required this.detections,
    required this.averageCentsDeviation,
    required this.practiceTargetNames,
  });

  final String report;
  final List<NoteDetectionResult> detections;
  final double? averageCentsDeviation;
  final List<String> practiceTargetNames;
}

class PracticeTarget {
  const PracticeTarget({
    required this.noteName,
    required this.midi,
    required this.frequency,
  });

  final String noteName;
  final int midi;
  final double frequency;
}

class NoteDetectionResult {
  const NoteDetectionResult({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.basicPitchMidi,
    required this.basicPitchNoteName,
    required this.amplitude,
    required this.pyinFrequency,
    required this.crepeFrequency,
    required this.yinFrequency,
    required this.targetNoteName,
    required this.targetFrequency,
    required this.centsDeviation,
    required this.status,
    required this.unavailableReason,
  });

  final int index;
  final double startTime;
  final double endTime;
  final int basicPitchMidi;
  final String basicPitchNoteName;
  final double amplitude;
  final double? pyinFrequency;
  final double? crepeFrequency;
  final double? yinFrequency;
  final String? targetNoteName;
  final double? targetFrequency;
  final double? centsDeviation;
  final String? status;
  final String? unavailableReason;
}

class PitchService {
  static const String _analysisEndpoint = 'http://3.107.222.157:8000/analyze';
  static const String _feedbackEndpoint = 'http://3.107.222.157:8000/feedback';
  // static const String _ollamaEndpoint =
  //     'http://192.168.2.115:11434/api/generate';
  //static const String _ollamaModel = 'gemma4:e2b-it-qat';
  static const int _frameSize = 2048;
  static const int _hopSize = 512;
  static const Duration _requestTimeout = Duration(seconds: 300);
  static const Duration _feedbackRequestTimeout = Duration(seconds: 300);
  static const List<int> _aMajorMidi = [69, 71, 73, 74, 76, 78, 80, 81];

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
      throw const PitchAnalysisException('Recording file not found.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 44) {
      throw const PitchAnalysisException(
        'Recording is empty or is not a valid WAV file.',
      );
    }

    final byteData = ByteData.sublistView(bytes);
    var chunkOffset = 12;
    int? dataOffset;
    int? dataLength;

    while (chunkOffset + 8 <= bytes.length) {
      final chunkSize = byteData.getUint32(chunkOffset + 4, Endian.little);
      final chunkDataOffset = chunkOffset + 8;
      if (chunkDataOffset + chunkSize > bytes.length) {
        throw const PitchAnalysisException('WAV data chunk is incomplete.');
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
      throw const PitchAnalysisException(
        'PCM data was not found in the WAV file.',
      );
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

    for (
      var offset = 0;
      offset <= samples.length - _frameSize;
      offset += _hopSize
    ) {
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
        report.writeln(
          "No valid pitch detected. Check if audio is too quiet or noisy.",
        );
        return report.toString();
      }

      final midi = hzToMidi(detectedFrequency);
      final centsDiff = (midi - targetMidi) * 100;
      final status = centsDiff > errorCents
          ? "Too Sharp (High)"
          : centsDiff < -errorCents
          ? "Too Flat (Low)"
          : "Accurate";

      report.writeln(
        "Detected Frequency: ${detectedFrequency.toStringAsFixed(2)} Hz",
      );
      report.writeln(
        "Difference: ${centsDiff > 0 ? '+' : ''}${centsDiff.toStringAsFixed(1)} cents\n",
      );
      report.writeln("Result: $status");
    } on PitchAnalysisException catch (error) {
      report.writeln(error.message);
    }

    return report.toString();
  }

  String buildFeedbackPrompt(SegmentedAnalysisResult result) {
    final isTargetedPractice = result.practiceTargetNames.isNotEmpty;
    final buffer = StringBuffer()
      ..writeln('你是一位耐心、鼓励7至9岁孩子的小提琴老师。')
      ..writeln(
        isTargetedPractice
            ? '学生刚刚在一把位针对练习了：${result.practiceTargetNames.join('、')}。'
            : '学生刚刚在一把位拉了一遍A大调音阶。',
      )
      ..writeln('A大调音阶（一把位）的标准指法是：')
      ..writeln(
        'A4=A弦空弦, B4=A弦1指, C#5=A弦2指, D5=A弦3指, '
        'E5=E弦空弦, F#5=E弦1指, G#5=E弦2指, A5=E弦3指',
      )
      ..writeln()
      ..writeln('以下是每个音符的检测结果：');

    for (final note in result.detections) {
      if (note.centsDeviation == null) {
        buffer.writeln(
          '第${note.index}个音(${note.basicPitchNoteName}): '
          '${note.unavailableReason ?? '未能评分'}',
        );
        continue;
      }

      final status = switch (note.status) {
        'accurate' => '音准准确',
        'tooSharp' => '偏高${note.centsDeviation!.toStringAsFixed(1)}音分',
        'tooFlat' => '偏低${note.centsDeviation!.abs().toStringAsFixed(1)}音分',
        _ => '未能评分',
      };
      buffer.writeln('第${note.index}个音(${note.basicPitchNoteName}): $status');
    }

    buffer
      ..writeln('\n请你用中文，以鼓励为主的语气，给学生一段简短的反馈（150字以内）。')
      ..writeln('要求：')
      ..writeln('1.先肯定孩子已经做得好的地方，再选1到2个最需要关注的重点说。')
      ..writeln('2.只依据上面的检测结果说话；不能从音高数据判断、猜测或纠正手型、手指位置、握弓、姿势或身体问题。')
      ..writeln(
        '3.建议要简单、具体、能马上做，例如“把这个音慢慢拉3次，每次拉长一点，听听声音有没有更稳”“先听老师或调音器示范，再模仿一次”。不要使用“手指往前/往后”“放松手型”等技术动作。',
      )
      ..writeln('4.使用7至9岁孩子和家长都能听懂的短句和日常用语；不使用专业术语、音分、频率或复杂解释。')
      ..writeln(
        '5.如果检测不稳定、音符数量不对或无法评分，温和地说明“这次声音没有被清楚听出来”，建议在安静处把音拉长一点再试；不要责备孩子。',
      )
      ..writeln(
        '6.如果检测结果显示某一个音明显比其他音更需要练习，可以在最后建议孩子下次在页面上只选这个音，做一次“单音针对练习”。一次只推荐一个音，并说明“慢慢拉3次、每次拉长一点，听听声音有没有更稳”。',
      )
      ..writeln('7.语气积极自然，不要逐条罗列每个音符，不要给出医学、伤痛或纠正姿势的建议。')
      ..writeln(
        '8.仅当这是完整的8个音A大调音阶、这4个音都已评分，且前4个音(A4、B4、C#5、D5)全部偏高或全部偏低时，可以说“这4个音都朝同一个方向偏了一点，A弦本身有可能需要校音。请先请家长用调音器检查并校准A弦，再试一次。”；后4个音(E5、F#5、G#5、A5)全部偏高或全部偏低时，同样提示E弦有可能需要校音。必须使用“有可能”，不能把它说成确定原因；不满足上述全部条件时，不要建议校弦。',
      );
    return buffer.toString();
  }

  Future<String?> generateFeedback(SegmentedAnalysisResult result) async {
    if (result.detections.isEmpty) {
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_feedbackEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': buildFeedbackPrompt(result)}),
          )
          .timeout(_feedbackRequestTimeout);
      if (response.statusCode != 200) {
        developer.log(
          'Ollama feedback request failed: HTTP ${response.statusCode}',
          name: 'PitchService',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        developer.log(
          'Ollama feedback response was not a JSON object.',
          name: 'PitchService',
        );
        return null;
      }

      final feedback = decoded['response'];
      return feedback is String && feedback.trim().isNotEmpty
          ? feedback.trim()
          : null;
    } catch (error, stackTrace) {
      developer.log(
        '生成AI反馈失败',
        name: 'PitchService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<SegmentedAnalysisResult> analyzeAudioFileWithSegmentation(
    String filePath, {
    List<PracticeTarget> practiceTargets = const [],
  }) async {
    try {
      if (practiceTargets.length > 2) {
        throw const PitchAnalysisException(
          'Targeted practice supports up to two notes.',
        );
      }
      final noteEvents = await _fetchNoteEvents(filePath);
      noteEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      final floatBuffer = await decodeWavToFloatBuffer(filePath);
      final isTargetedPractice = practiceTargets.isNotEmpty;
      final isCompleteScale =
          !isTargetedPractice && noteEvents.length == _aMajorMidi.length;
      final detections = <NoteDetectionResult>[];
      final report = StringBuffer()
        ..writeln('--- Basic Pitch Segment Analysis ---')
        ..writeln('Basic Pitch detected ${noteEvents.length} notes.');

      if (isTargetedPractice) {
        report.writeln(
          'Targeted practice: matching each segment to the closest selected note '
          '(${practiceTargets.map((target) => target.noteName).join(', ')}).\n',
        );
      } else if (isCompleteScale) {
        report.writeln('已识别完整的 8 个音，按 A 大调音阶顺序评分。\n');
      } else {
        report.writeln(
          '本次识别到 ${noteEvents.length} 个音，未构成完整的 8 音 A 大调音阶。'
          '已根据每段识别到的音高，展示可评分的部分结果；'
          '未识别到的音不会计入本次评分。\n',
        );
      }

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

        report.writeln(
          '${index + 1}. Basic Pitch: ${_midiToNoteName(event.pitchMidi)} '
          '(${event.startTime.toStringAsFixed(2)}-${event.endTime.toStringAsFixed(2)} s)',
        );
        report.writeln('   Confidence: ${event.amplitude.toStringAsFixed(2)}');
        report.writeln('   pYIN: ${_formatFrequency(event.pyinFreq)}');
        report.writeln('   CREPE: ${_formatFrequency(event.crepeFreq)}');

        final scaleTargetMidi = isTargetedPractice
            ? null
            : isCompleteScale
            ? _aMajorMidi[index]
            : _findClosestScaleTargetMidi(event.pitchMidi);
        double? targetFrequency = scaleTargetMidi == null
            ? null
            : 440.0 * pow(2, (scaleTargetMidi - 69) / 12);
        String? targetNoteName = scaleTargetMidi == null
            ? null
            : _midiToNoteName(scaleTargetMidi);
        double? detectedFrequency;
        String? unavailableReason;

        if (endSample <= startSample || endSample - startSample < _frameSize) {
          report.writeln('   YIN: unavailable (segment is too short).\n');
          unavailableReason = 'Segment is too short for YIN analysis.';
        } else {
          detectedFrequency = detectPitchFromSamples(
            floatBuffer.sublist(startSample, endSample),
          );
          if (detectedFrequency == null) {
            report.writeln('   YIN: unavailable (no stable pitch detected).\n');
            unavailableReason = 'No stable YIN pitch detected.';
          } else {
            report.writeln('   YIN: ${_formatFrequency(detectedFrequency)}');
          }
        }

        double? centsDeviation;
        String? status;
        if (isTargetedPractice && detectedFrequency != null) {
          final closestTarget = _findClosestPracticeTarget(
            detectedFrequency,
            practiceTargets,
          );
          targetFrequency = closestTarget.frequency;
          targetNoteName = closestTarget.noteName;
        }

        if ((scaleTargetMidi != null || isTargetedPractice) &&
            detectedFrequency != null &&
            targetFrequency != null) {
          centsDeviation =
              1200 * (log(detectedFrequency / targetFrequency) / ln2);
          status = centsDeviation.abs() <= errorCents
              ? 'accurate'
              : centsDeviation > 0
              ? 'tooSharp'
              : 'tooFlat';
          report.writeln(
            '   Target: $targetNoteName '
            '(${targetFrequency.toStringAsFixed(2)} Hz)',
          );
          report.writeln(
            '   Deviation: ${centsDeviation.toStringAsFixed(1)} cents',
          );
          report.writeln(
            '   Status: ${status == 'accurate'
                ? '✅ Accurate'
                : status == 'tooSharp'
                ? '↗️ Too Sharp'
                : '↘️ Too Flat'}\n',
          );
        } else if (!isTargetedPractice && scaleTargetMidi == null) {
          report.writeln('   此段未匹配到 A 大调音阶中的目标音，暂不评分。\n');
        }

        detections.add(
          NoteDetectionResult(
            index: index + 1,
            startTime: event.startTime,
            endTime: event.endTime,
            basicPitchMidi: event.pitchMidi,
            basicPitchNoteName: _midiToNoteName(event.pitchMidi),
            amplitude: event.amplitude,
            pyinFrequency: event.pyinFreq,
            crepeFrequency: event.crepeFreq,
            yinFrequency: detectedFrequency,
            targetNoteName: targetNoteName,
            targetFrequency: targetFrequency,
            centsDeviation: centsDeviation,
            status: status,
            unavailableReason: unavailableReason,
          ),
        );
      }

      final scoredDetections = detections
          .where((detection) => detection.centsDeviation != null)
          .toList();
      final averageCentsDeviation = scoredDetections.isEmpty
          ? null
          : scoredDetections
                    .map((detection) => detection.centsDeviation!)
                    .reduce((sum, deviation) => sum + deviation) /
                scoredDetections.length;
      return SegmentedAnalysisResult(
        report: report.toString(),
        detections: detections,
        averageCentsDeviation: averageCentsDeviation,
        practiceTargetNames: practiceTargets
            .map((target) => target.noteName)
            .toList(growable: false),
      );
    } on TimeoutException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return _failedSegmentedAnalysis(
        'Audio analysis timed out. Confirm the backend service is running and try again.',
      );
    } on SocketException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return _failedSegmentedAnalysis(
        'Unable to connect to the audio analysis service. Confirm the backend is running.',
      );
    } on http.ClientException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return _failedSegmentedAnalysis(
        'Audio analysis network error: ${error.message}',
      );
    } on PitchAnalysisException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return _failedSegmentedAnalysis(
        'The audio analysis service could not process this recording.',
      );
    } on FormatException catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return _failedSegmentedAnalysis(
        'The audio analysis service returned unrecognized data.',
      );
    } catch (error, stackTrace) {
      _logAnalysisError(error, stackTrace);
      return _failedSegmentedAnalysis(
        'Audio analysis failed: $error (${error.runtimeType})',
      );
    }
  }

  SegmentedAnalysisResult _failedSegmentedAnalysis(String report) {
    return SegmentedAnalysisResult(
      report: report,
      detections: const [],
      averageCentsDeviation: null,
      practiceTargetNames: const [],
    );
  }

  PracticeTarget _findClosestPracticeTarget(
    double detectedFrequency,
    List<PracticeTarget> practiceTargets,
  ) {
    return practiceTargets.reduce((closest, candidate) {
      final closestDeviation =
          (1200 * (log(detectedFrequency / closest.frequency) / ln2)).abs();
      final candidateDeviation =
          (1200 * (log(detectedFrequency / candidate.frequency) / ln2)).abs();
      return candidateDeviation < closestDeviation ? candidate : closest;
    });
  }

  int? _findClosestScaleTargetMidi(int detectedMidi) {
    final closestMidi = _aMajorMidi.reduce((closest, candidate) {
      return (candidate - detectedMidi).abs() < (closest - detectedMidi).abs()
          ? candidate
          : closest;
    });
    return (closestMidi - detectedMidi).abs() <= 1 ? closestMidi : null;
  }

  void _logAnalysisError(Object error, StackTrace stackTrace) {
    print('音频分析失败，异常详情: $error');
    print('异常类型: ${error.runtimeType}');
    print('堆栈信息: $stackTrace');
  }

  String _midiToNoteName(int midi) {
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return '${noteNames[midi % 12]}${(midi ~/ 12) - 1}';
  }

  String _formatFrequency(double? frequency) {
    if (frequency == null || frequency <= 0) {
      return 'unavailable';
    }
    return '${frequency.toStringAsFixed(2)} Hz';
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
      throw PitchAnalysisException(
        detail?.toString() ??
            'The service returned HTTP ${response.statusCode}.',
      );
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
        pitchMidi: (value['pitch_midi'] as num).round(),
        amplitude: (value['amplitude'] as num).toDouble(),
        pyinFreq: (value['pyin_freq'] as num?)?.toDouble(),
        crepeFreq: (value['crepe_freq'] as num?)?.toDouble(),
      );
    }).toList();
  }
}

class _NoteEvent {
  const _NoteEvent({
    required this.startTime,
    required this.endTime,
    required this.pitchMidi,
    required this.amplitude,
    required this.pyinFreq,
    required this.crepeFreq,
  });

  final double startTime;
  final double endTime;
  final int pitchMidi;
  final double amplitude;
  final double? pyinFreq;
  final double? crepeFreq;
}

class PitchAnalysisException implements Exception {
  const PitchAnalysisException(this.message);

  final String message;

  @override
  String toString() => 'PitchAnalysisException: $message';
}
