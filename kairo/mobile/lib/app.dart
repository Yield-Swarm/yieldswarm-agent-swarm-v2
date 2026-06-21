import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'shared/theme/kairo_theme.dart';

class KairoApp extends ConsumerWidget {
  const KairoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Kairo',
      debugShowCheckedModeBanner: false,
      theme: kairoLightTheme,
      darkTheme: kairoDarkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
