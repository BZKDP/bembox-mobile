import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';

/// Стартовый экран. Пока [AuthController.bootstrap] проверяет сохранённую сессию
/// (статус `unknown`), показываем логотип. Как только статус определится, роутер
/// сам уведёт на /home (см. redirect в router.dart).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Запускаем проверку сессии после первого кадра (provider уже готов).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BemColors.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/wordmark-bembox-coral.png', width: 160),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: BemColors.coral),
            ),
          ],
        ),
      ),
    );
  }
}
