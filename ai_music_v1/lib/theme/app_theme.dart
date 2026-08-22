import 'package:flutter/material.dart';

/// ============================================================
/// 设计系统 · 杏桃暖阳（Apricot Sunshine）
/// ------------------------------------------------------------
/// 使用方式：
///   1. 把这个文件放到 lib/theme/app_theme.dart
///   2. main.dart 里 MaterialApp(theme: AppTheme.light)
///   3. 页面里颜色一律用 AppColors.xxx，不要再手写十六进制色值
/// ============================================================

class AppColors {
  AppColors._();

  // 主色：珊瑚橙 —— 用于主按钮、录音按钮、选中态
  static const primary = Color(0xFFFF8C61);
  static const primaryDark = Color(0xFFE86F42); // 按下/深色文字用

  // 辅助色：暖黄 —— 用于次级强调、进度条、装饰
  static const secondary = Color(0xFFFFC15E);

  // 浅色调：用于未选中的音符chip背景、卡片底色
  static const accentLight = Color(0xFFFFDAB4);

  // 背景色：整个App的页面底色（暖米白，不是纯白）
  static const background = Color(0xFFFFF3EA);

  // 卡片/容器表面色：比background略亮，用于结果卡片
  static const surface = Color(0xFFFFFBF7);

  // 音准状态色（保留"暖=偏高，冷=偏低"的直觉隐喻，是这套配色里唯一的冷色例外）
  static const statusAccurate = Color(0xFF6FCF97); // 准确：清新绿
  static const statusSharp = Color(0xFFFF6F59); // 偏高：暖红
  static const statusFlat = Color(0xFF5FA8D3); // 偏低：柔和蓝

  // 文字色：不用纯黑，用带暖调的深棕，跟背景更协调
  static const textPrimary = Color(0xFF5C3620);
  static const textSecondary = Color(0xFFA0714A);
  static const textMuted = Color(0xFFC79B78);

  // 边框/分割线
  static const border = Color(0xFFF5D9C2);
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0; // 小控件、输入框
  static const md = 16.0; // 卡片
  static const pill = 999.0; // 音符chip、录音按钮，走"药丸/圆形"造型
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.statusSharp,
      ),

      // AppBar：去掉默认阴影，改成跟背景同色调，更"融入"而不是"悬浮"
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      // 文字层级：标题用深棕加粗，正文用textPrimary，说明文字用textSecondary
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),

      // 音符选择chip（FilterChip）的默认样式
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.accentLight.withValues (alpha: 0.4),
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // 悬浮录音按钮
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // 卡片（结果展示、历史记录条目）
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // 图标默认色
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );
  }
}