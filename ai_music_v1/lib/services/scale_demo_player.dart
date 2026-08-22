import 'package:audioplayers/audioplayers.dart';

/// 播放完整A大调上行音阶示范音频。
/// 播放 assets/audio/ 下的一整段录音文件（一次演奏完整的上行音阶）。
class ScaleDemoPlayer {
  final AudioPlayer _player = AudioPlayer();

  // 换成你实际的文件名，要跟 assets/audio/ 下的文件完全一致（含大小写、后缀）
  static const String _scaleAsset = 'audio/violin-a-major_half.wav';

  /// 播放完整音阶录音，播放结束后自动完成
  Future<void> playScale() async {
    await _player.play(AssetSource(_scaleAsset));
    await _player.onPlayerComplete.first;
  }

  /// 中途停止播放
  void stop() {
    _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}