import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/local/local_storage_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/navigation/main_navigation_shell.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();

  runApp(
    const ProviderScope(
      child: QuickChatApp(),
    ),
  );
}

class QuickChatApp extends ConsumerWidget {
  const QuickChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'QuickChat Mesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: authState.when(
        data: (user) => user == null ? const OnboardingScreen() : const MainNavigationShell(),
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => const OnboardingScreen(),
      ),
    );
  }
}
