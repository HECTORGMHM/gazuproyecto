import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'utils/firebase_startup_guard.dart';
import 'utils/constants.dart';
import 'widgets/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    FirebaseStartupGuard.validateCurrentPlatform();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const GazuApp());
  } catch (error) {
    runApp(GazuStartupIssueApp(message: error.toString()));
  }
}

class GazuApp extends StatelessWidget {
  const GazuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<AuthService>(
          create: (ctx) => AuthService(
            firestoreService: ctx.read<FirestoreService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Gazu',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(AppColors.primaryOrange),
          ),
          scaffoldBackgroundColor: const Color(AppColors.scaffoldCharcoal),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class GazuStartupIssueApp extends StatelessWidget {
  const GazuStartupIssueApp({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gazu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(AppColors.primaryOrange),
        ),
        scaffoldBackgroundColor: const Color(AppColors.scaffoldCharcoal),
        useMaterial3: true,
      ),
      home: _StartupIssueScreen(message: message),
    );
  }
}

class _StartupIssueScreen extends StatelessWidget {
  const _StartupIssueScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Configuración incompleta de Flutter/Firebase',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(message),
                    const SizedBox(height: 16),
                    const Text(
                      'Pasos recomendados:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Ejecuta `flutterfire configure` en la raíz del proyecto.'),
                    const Text('2. Agrega `android/app/google-services.json`.'),
                    const Text('3. Agrega `ios/Runner/GoogleService-Info.plist`.'),
                    const Text('4. Vuelve a correr `flutter pub get`, `flutter analyze` y `flutter test`.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
