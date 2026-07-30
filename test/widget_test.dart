import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classforge/main.dart';

void main() {
  testWidgets('app launches with MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
