import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/bem_theme.dart';
import 'router.dart';

/// Корневой виджет приложения.
class BemboxApp extends ConsumerWidget {
  const BemboxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'bembox',
      debugShowCheckedModeBanner: false,
      theme: BemTheme.light(),
      routerConfig: router,
    );
  }
}
