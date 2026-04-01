import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GrandparentGuardianApp());

    // Verify that the safe state is rendered initially
    expect(find.text('Protection Active'), findsOneWidget);
  });
}
