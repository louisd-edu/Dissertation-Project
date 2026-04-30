// Widget tests GraphsScreen
// FakeAppState subclass provides pre-loaded data so no network calls
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:veridose/screens/graphs/graphs_screen.dart';
import 'package:veridose/services/app_state.dart';
import 'test_helpers.dart';

class _FakeAppState extends AppState {
  final int _streak;
  final int _weeks;
  final Map<String, int> _stats;

  _FakeAppState({
    int streak = 0,
    int weeks = 0,
    Map<String, int> stats = const {
      'taken': 0,
      'skipped': 0,
      'missed': 0,
      'pending': 0,
      'expected': 0,
    },
  })  : _streak = streak,
        _weeks = weeks,
        _stats = stats;

  @override
  int get dailyStreak => _streak;

  @override
  int get weeksCompleted => _weeks;

  @override
  Map<String, int> get weeklyDoseBreakdown => _stats;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadStats() async {}
}

Widget _buildSubject(_FakeAppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: GraphsScreen()),
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

  group('GraphsScreen rendering (FR-06 / FR-07 / FR-08)', () {
    testWidgets('renders the "Progress" screen title', (tester) async {
      await tester.pumpWidget(_buildSubject(_FakeAppState()));
      await tester.pump();
      expect(find.text('Progress'), findsOneWidget);
    });

    testWidgets('shows 0% adherence when no doses are recorded', (tester) async {
      await tester.pumpWidget(_buildSubject(_FakeAppState()));
      await tester.pump();
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('calculates and displays the correct adherence percentage',
        (tester) async {
      // 4 / 7 = 57 %
      final state = _FakeAppState(stats: {
        'taken': 4,
        'skipped': 0,
        'missed': 0,
        'pending': 3,
        'expected': 7,
      });
      await tester.pumpWidget(_buildSubject(state));
      await tester.pump();
      expect(find.text('57%'), findsOneWidget);
    });

    testWidgets('shows 100% when all expected doses are taken', (tester) async {
      final state = _FakeAppState(stats: {
        'taken': 7,
        'skipped': 0,
        'missed': 0,
        'pending': 0,
        'expected': 7,
      });
      await tester.pumpWidget(_buildSubject(state));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('renders all four dose-breakdown labels', (tester) async {
      await tester.pumpWidget(_buildSubject(_FakeAppState()));
      await tester.pump();
      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('renders the "Daily Streak" stat card', (tester) async {
      await tester.pumpWidget(_buildSubject(_FakeAppState()));
      await tester.pump();
      expect(find.text('Daily Streak'), findsOneWidget);
    });

    testWidgets('renders the "Weeks Completed" stat card', (tester) async {
      await tester.pumpWidget(_buildSubject(_FakeAppState()));
      await tester.pump();
      expect(find.text('Weeks Completed'), findsOneWidget);
    });

    testWidgets('displays the current daily streak value', (tester) async {
      final state = _FakeAppState(streak: 5);
      await tester.pumpWidget(_buildSubject(state));
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('displays the current weeks-completed value', (tester) async {
      final state = _FakeAppState(weeks: 3);
      await tester.pumpWidget(_buildSubject(state));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows "This Week\'s Adherence" section heading', (tester) async {
      await tester.pumpWidget(_buildSubject(_FakeAppState()));
      await tester.pump();
      expect(find.text("This Week's Adherence"), findsOneWidget);
    });
  });
}
