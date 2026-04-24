import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'services/app_state.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.get('PROJECT_URL'),
    anonKey: dotenv.get('ANON_KEY'),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MedicalAdherenceTrackingApp(),
    ),
  );

  // Initialize notifications in the background so app startup + auth is not blocked.
  unawaited(NotificationService.instance.initialize());
}

class MedicalAdherenceTrackingApp extends StatelessWidget {
  const MedicalAdherenceTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedicalAdherenceTrackingApp',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const Duration _startupValidationTimeout = Duration(seconds: 10);
  static const Duration _signOutTimeout = Duration(seconds: 4);
  static const Duration _hardValidationTimeout = Duration(seconds: 14);

  String? _activeValidationUserId;
  Future<bool>? _activeValidationFuture;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _validateSession(String userId) async {
    if (Supabase.instance.client.auth.currentSession?.user == null) {
      context.read<AppState>().reset();
      return false;
    }

    final isProvisioned = await context
      .read<AppState>()
      .loadAll(userId: userId)
      .timeout(_startupValidationTimeout, onTimeout: () => false);
    if (!isProvisioned) {
      unawaited(
        Supabase.instance.client.auth
            .signOut()
            .timeout(_signOutTimeout)
            .catchError((_) {}),
      );
      if (mounted) {
        context.read<AppState>().reset();
      }
      return false;
    }

    return true;
  }

  Future<bool> _validationFutureFor(String userId) {
    if (_activeValidationFuture == null || _activeValidationUserId != userId) {
      _activeValidationUserId = userId;
      _activeValidationFuture = _validateSession(userId).timeout(
        _hardValidationTimeout,
        onTimeout: () => false,
      );
    }
    return _activeValidationFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        final userId = session?.user.id;

        if (userId == null) {
          _activeValidationUserId = null;
          _activeValidationFuture = null;
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          key: ValueKey(userId),
          future: _validationFutureFor(userId),
          builder: (context, validationSnapshot) {
            if (validationSnapshot.connectionState != ConnectionState.done) {
              return const _AuthLoadingScreen();
            }

            if (validationSnapshot.data == true) {
              return const MainShell();
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}