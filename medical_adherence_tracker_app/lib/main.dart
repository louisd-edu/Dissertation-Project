import 'package:flutter/material.dart';
import 'package:medtrack/home.dart';
import 'package:medtrack/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'services/app_state.dart';
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
}

class MedicalAdherenceTrackingApp extends StatelessWidget {
  const MedicalAdherenceTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedicalAdherenceTrackingApp',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      //home: const MainShell(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      await context.read<AppState>().loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          //return const MainShell();
        }
          //return const LoginScreen();
          return const MainHomeScreen();
      },
    );
  }
}