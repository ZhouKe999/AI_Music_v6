import 'package:flutter/material.dart';

class PitchDisplay extends StatelessWidget {
  final double? pitch;

  const PitchDisplay({super.key, this.pitch});

  @override
  Widget build(BuildContext context) {
    return Text(
      pitch != null ? "当前音高: ${pitch!.toStringAsFixed(2)} Hz" : "未检测到音高",
      style: const TextStyle(fontSize: 24),
    );
  }
}
