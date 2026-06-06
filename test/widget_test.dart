import 'package:flutter_test/flutter_test.dart';

import 'package:interflex/main.dart';

void main() {
  testWidgets('shows login screen with create account option', (tester) async {
    await tester.pumpWidget(const InterFlexApp());
    await tester.pumpAndSettle();

    expect(find.text('INTERFLEX'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Country national ID number'), findsOneWidget);
  });
}
