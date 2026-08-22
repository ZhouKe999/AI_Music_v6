import 'package:flutter/material.dart';
import 'package:ai_music_v1/theme/app_theme.dart';

/// 单个音符的检测状态，用于给示意条上的点染色。
/// 首页录音前全部是 neutral；结果页分析完之后按检测结果传入。
enum NoteStatus { neutral, accurate, sharp, flat }

/// 音阶示意条：横向展示一组音符按音高走势排列的小圆点。
/// - 首页：statuses 不传，全部显示为中性色，起到"预览接下来要拉什么"的作用
/// - 结果页：传入每个音的检测状态，起到"一眼看出哪几个音有问题"的可视化反馈作用
class ScaleStrip extends StatelessWidget {
  final List<String> noteLabels;
  final List<NoteStatus>? statuses;

  const ScaleStrip({
    super.key,
    required this.noteLabels,
    this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStatuses =
        statuses ?? List.filled(noteLabels.length, NoteStatus.neutral);
    assert(
      effectiveStatuses.length == noteLabels.length,
      'statuses 的长度必须和 noteLabels 一致',
    );

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
          Text('A大调音阶（上行）', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _ScaleStripPainter(
                noteLabels: noteLabels,
                statuses: effectiveStatuses,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleStripPainter extends CustomPainter {
  final List<String> noteLabels;
  final List<NoteStatus> statuses;

  _ScaleStripPainter({required this.noteLabels, required this.statuses});

  Color _dotColor(NoteStatus status) {
    switch (status) {
      case NoteStatus.accurate:
        return AppColors.statusAccurate;
      case NoteStatus.sharp:
        return AppColors.statusSharp;
      case NoteStatus.flat:
        return AppColors.statusFlat;
      case NoteStatus.neutral:
        return AppColors.accentLight;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 画5条水平参考线，营造五线谱的既视感（不追求真实乐理还原）
    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    const lineCount = 5;
    const topPad = 8.0;
    const bottomPad = 26.0; // 给底部音名标签留空间
    final staffHeight = size.height - topPad - bottomPad;

    for (int i = 0; i < lineCount; i++) {
      final y = topPad + staffHeight * i / (lineCount - 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final n = noteLabels.length;
    if (n < 2) return;
    const leftPad = 16.0;
    const rightPad = 16.0;
    final usableWidth = size.width - leftPad - rightPad;

    for (int i = 0; i < n; i++) {
      final x = leftPad + usableWidth * i / (n - 1);
      final t = i / (n - 1);
      // 上行音阶：序号越大音越高，y越小（画布坐标系y轴向下）
      final y = topPad + staffHeight * (1 - t);
      final isLast = i == n - 1;

      canvas.drawCircle(
        Offset(x, y),
        isLast ? 8 : 7,
        Paint()..color = _dotColor(statuses[i]),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: noteLabels[i],
          style: TextStyle(
            fontSize: 10,
            color: isLast ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - bottomPad + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScaleStripPainter oldDelegate) {
    return oldDelegate.statuses != statuses ||
        oldDelegate.noteLabels != noteLabels;
  }
}