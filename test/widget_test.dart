import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incident_reporting_frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartIncidentApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
