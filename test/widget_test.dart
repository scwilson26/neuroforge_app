// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:neuroforge_app/main.dart';

void main() {
  testWidgets('FrontPage shows inline generate button', (WidgetTester tester) async {
    await tester.pumpWidget(const SpacedApp());
    expect(find.text('Choose files & Generate'), findsOneWidget);
  });
}
