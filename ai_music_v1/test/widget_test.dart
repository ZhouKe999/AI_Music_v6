import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_music_v1/main.dart';

void main() {
  testWidgets('Home page renders music analysis controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('AI Violin Teacher'), findsOneWidget);
    expect(find.text('B4'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
