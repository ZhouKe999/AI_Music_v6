import 'package:flutter/material.dart';
import 'package:ai_music_v1/theme/app_theme.dart';
import 'package:ai_music_v1/services/pitch_service.dart';

/// 结果页：录音分析完成后跳转到这里，专门展示检测报告和AI反馈。
/// 首页只负责录音，不再堆结果内容。
class ResultsPage extends StatelessWidget {
  final SegmentedAnalysisResult analysis;
  final String? feedback;

  const ResultsPage({
    super.key,
    required this.analysis,
    this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("检测结果")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 检测报告（CREPE/YIN/Target/Deviation等数据）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                analysis.report,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // AI老师反馈：单独用醒目一点的卡片区分开，跟纯数据报告区分层级
            if (feedback != null) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    "AI老师反馈",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  feedback!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  "AI反馈暂不可用。",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("返回继续练习"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}