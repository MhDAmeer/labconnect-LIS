import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labconnect_admin/features/login/helix_background.dart';

void main() {
  testWidgets('helix background paints and animates without errors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HelixBackground())),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HelixBackground), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Removing it must stop the ticker (a leaked ticker fails the test).
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
  });
}
