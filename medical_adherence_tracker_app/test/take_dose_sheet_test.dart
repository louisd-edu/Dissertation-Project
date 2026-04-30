// Widget tests TakeDoseSheet
// Network calls prevented by FaeAppState , rendering only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:veridose/models/models.dart';
import 'package:veridose/screens/home/take_dose_sheet.dart';
import 'package:veridose/services/app_state.dart';
import 'test_helpers.dart';

class _FakeAppState extends AppState {
  @override
  bool get isLoading => false;

  @override
  Future<void> loadStats() async {}

  @override
  Future<void> loadTodaySchedule() async {}
}

// Test data
final _planMetformin = MedicationPlan(
  id: 'plan-uuid-001',
  name: 'Metformin',
  planName: 'Morning Metformin',
  dosage: 500,
  units: 'mg',
  frequency: ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'],
  time: '08:00',
  startDate: DateTime(2026, 1, 1),
  patientId: 'pat-uuid-001',
  doctorId: 'doc-uuid-001',
);

final _planSalbutamol = MedicationPlan(
  id: 'plan-uuid-002',
  name: 'Salbutamol',
  planName: 'Salbutamol Inhaler',
  dosage: 100,
  units: 'mcg',
  frequency: ['mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'],
  time: '08:00',
  startDate: DateTime(2026, 1, 1),
  patientId: 'pat-uuid-002',
  doctorId: 'doc-uuid-001',
);

ScheduledDose _pendingDose(MedicationPlan plan) => ScheduledDose(
      plan: plan,
      dose: null,
      scheduledTime: DateTime(2026, 4, 21, 8, 0),
    );

ScheduledDose _takenDose(MedicationPlan plan) => ScheduledDose(
      plan: plan,
      dose: Dose(
        id: 'dose-uuid-001',
        status: DoseStatus.taken,
        planId: plan.id,
        takenAt: DateTime(2026, 4, 21, 8, 5),
        scheduledFor: DateTime(2026, 4, 21, 8, 0),
      ),
      scheduledTime: DateTime(2026, 4, 21, 8, 0),
    );

Widget _buildSubject(ScheduledDose scheduledDose) =>
    ChangeNotifierProvider<AppState>.value(
      value: _FakeAppState(),
      child: MaterialApp(
        home: Scaffold(
          body: TakeDoseSheet(scheduledDose: scheduledDose),
        ),
      ),
    );


// Tests
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : null,
    );

    await initSupabaseForTest();
  });

  group('TakeDoseSheet — rendering (FR-04)', () {
    testWidgets('shows "Medication Reminder" label', (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(find.text('Medication Reminder'), findsOneWidget);
    });

    testWidgets('displays the medication name from the plan', (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(find.text('Metformin'), findsOneWidget);
    });

    testWidgets('displays the dosage label (amount + units)', (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(find.text('500 mg'), findsOneWidget);
    });

    testWidgets('displays a different medication name when plan changes',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planSalbutamol)));
      await tester.pump();
      expect(find.text('Salbutamol'), findsOneWidget);
      expect(find.text('100 mcg'), findsOneWidget);
    });

    // Camera evidence area 

    testWidgets('shows the camera capture area before any media is recorded',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('shows the "Tap to record a photo" instruction text',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(
        find.text('Tap to record a photo.\nPress and hold to record video.'),
        findsOneWidget,
      );
    });

    testWidgets('shows Photo and Video capture buttons before media is added',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    });

    // Action buttons 

    testWidgets('shows both Skip and Take action buttons', (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Take'), findsOneWidget);
    });

    testWidgets('Take button is enabled before any interaction', (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      final takeBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Take'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(takeBtn.onPressed, isNotNull);
    });

    testWidgets('Skip button is enabled before any interaction', (tester) async {
      await tester.pumpWidget(_buildSubject(_pendingDose(_planMetformin)));
      await tester.pump();
      final skipBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Skip'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(skipBtn.onPressed, isNotNull);
    });

    // Already-taken dose 

    testWidgets('still shows medication name for an already-taken dose',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_takenDose(_planMetformin)));
      await tester.pump();
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);
    });
  });
}
