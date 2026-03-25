import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beta/main.dart';

void main() {
  testWidgets('MapScreen shows loading indicator on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}