import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_bag/core/theme/app_theme.dart';
import 'package:magic_bag/providers/ui/theme_provider.dart';
import 'core/di/service_locator.dart';
import 'presentation/pages/control_page.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() {
  // 1. Preservar el splash nativo
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // 1. Inicializamos GetIt
  setupLocator();

  runApp(const ProviderScope(child: MagicBagApp()));
}

class MagicBagApp extends ConsumerWidget {
  const MagicBagApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControlProvider);

    Future.delayed(const Duration(seconds: 2), () {
      FlutterNativeSplash.remove(); // Liberamos el splash para mostrar la UI
    });

    return MaterialApp(
      title: 'Magic Bag Terminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const ControlPage(),
    );
  }
}
