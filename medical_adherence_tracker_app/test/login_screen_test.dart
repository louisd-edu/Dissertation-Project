// Widget tests LoginScreen
// These tests only check rendering, no network calls through submit button,
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:veridose/screens/auth/login_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildSubject() => const MaterialApp(home: LoginScreen());

  group('LoginScreen rendering (FR-01)', () {
    testWidgets('shows the "VeriDose" app title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('VeriDose'), findsOneWidget);
    });

    testWidgets('shows the "Welcome" heading', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('renders exactly two text fields (email and password)', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('renders the Sign In button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Sign In button is enabled before any tap', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('does not show an error message on first render', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Invalid email or password.'), findsNothing);
    });

    testWidgets('has a password visibility toggle icon button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('toggles password visibility when the icon is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });
}
