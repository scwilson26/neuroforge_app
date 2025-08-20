// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:neuroforge_app/main.dart';

void main() {
  testWidgets('FrontPage shows Upload Study Notes and navigates to UploadPage', (WidgetTester tester) async {
  await tester.pumpWidget(const SpacedApp());

    // Front page has the CTA button
    expect(find.text('Upload Study Notes'), findsOneWidget);

    // Tap the button to navigate to upload page
    await tester.tap(find.text('Upload Study Notes'));
    await tester.pumpAndSettle();

    // Upload page shows the generate button
    expect(find.text('Choose files & Generate'), findsOneWidget);
  });
}
