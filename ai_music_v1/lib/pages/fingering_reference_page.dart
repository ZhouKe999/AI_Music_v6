import 'package:flutter/material.dart';
import 'package:ai_music_v1/theme/app_theme.dart';

/// 单个音符对应的指法信息
class FingeringInfo {
  final String note;
  final String stringName; // 使用哪根弦：'G' / 'D' / 'A' / 'E'
  final int finger; // 0 = 空弦，1~4 = 第几指

  const FingeringInfo({
    required this.note,
    required this.stringName,
    required this.finger,
  });
}

/// A大调上行音阶（A4~A5）标准第一把位指法
/// 如果你的教学法指法不同，改这里对应的 stringName / finger 就行
const List<FingeringInfo> aMajorFingerings = [
  FingeringInfo(note: 'A4', stringName: 'A', finger: 0),
  FingeringInfo(note: 'B4', stringName: 'A', finger: 1),
  FingeringInfo(note: 'C#5', stringName: 'A', finger: 2),
  FingeringInfo(note: 'D5', stringName: 'A', finger: 3),
  FingeringInfo(note: 'E5', stringName: 'E', finger: 0),
  FingeringInfo(note: 'F#5', stringName: 'E', finger: 1),
  FingeringInfo(note: 'G#5', stringName: 'E', finger: 2),
  FingeringInfo(note: 'A5', stringName: 'E', finger: 3),
];

/// 指法参考页：完整列出A大调8个音各自的指板位置
class FingeringReferencePage extends StatelessWidget {
  const FingeringReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('指法参考')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: aMajorFingerings.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final info = aMajorFingerings[index];
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.note, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                FingerboardDiagram(info: info),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 指板示意图：4根弦（G D A E），高亮当前音所在的弦，
/// 并用一个圆点标出大致按弦位置（空弦靠左，指法号越大越靠右）
class FingerboardDiagram extends StatelessWidget {
  final FingeringInfo info;
  const FingerboardDiagram({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: CustomPaint(painter: _FingerboardPainter(info: info)),
    );
  }
}

class _FingerboardPainter extends CustomPainter {
  final FingeringInfo info;
  _FingerboardPainter({required this.info});

  // 从上到下按由低到高排列，符合大部分教材里指板图的画法习惯
  static const _strings = ['G', 'D', 'A', 'E'];

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 30.0;
    const rightPad = 16.0;
    final usableWidth = size.width - leftPad - rightPad;
    final stringGap = size.height / (_strings.length + 1);

    for (int i = 0; i < _strings.length; i++) {
      final y = stringGap * (i + 1);
      final isActive = _strings[i] == info.stringName;

      final linePaint = Paint()
        ..color = isActive ? AppColors.primary : AppColors.border
        ..strokeWidth = isActive ? 2.5 : 1.5;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        linePaint,
      );

      final stringLabel = TextPainter(
        text: TextSpan(
          text: _strings[i],
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      stringLabel.paint(canvas, Offset(4, y - stringLabel.height / 2));

      if (isActive) {
        // 手指位置：0=空弦(最靠左)，1~4指依次往右排开
        final posT = info.finger / 4;
        final x = leftPad + usableWidth * posT;
        canvas.drawCircle(Offset(x, y), 8, Paint()..color = AppColors.primary);

        final fingerLabel = info.finger == 0 ? '空弦' : '${info.finger}指';
        final labelPainter = TextPainter(
          text: TextSpan(
            text: fingerLabel,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(x - labelPainter.width / 2, y - 26),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FingerboardPainter oldDelegate) {
    return oldDelegate.info.note != info.note;
  }
}