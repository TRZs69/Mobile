import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LevelyApp());
    // Basic test to ensure the app boots up without crashing
    expect(find.byType(LevelyApp), findsOneWidget);
  });
}
