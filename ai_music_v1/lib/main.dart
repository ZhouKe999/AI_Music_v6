import 'package:flutter/material.dart';
import 'package:ai_music_v1/pages/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Violin Teacher',
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
