import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Бренд bembox.
const _coral = Color(0xFFFF7547);
const _coralDeep = Color(0xFFE8551F);
const _beige = Color(0xFFFFFCF6);
const _ink = Color(0xFF1F1A16);
const _mute = Color(0xFF8A8178);

/// Нативный онбординг (первый запуск). Чистый Flutter — НЕ webview. Три экрана,
/// последний просит геопозицию. По завершении вызывает [onFinish] (там сохраняем
/// флаг и переходим в WebView-оболочку).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = <_PageData>[
    _PageData(
      image: 'assets/onboarding/onb-1.png',
      title: 'Продукты и услуги\nза 15 минут к двери',
      subtitle: 'Привезём из магазина рядом и поможем с бытовыми делами — быстро.',
    ),
    _PageData(
      image: 'assets/onboarding/onb-2.png',
      title: 'Кофе, вода, вынос\nмусора, посылки',
      subtitle: 'Всё в пару тапов — выбираете услугу, остальное берём на себя.',
    ),
    _PageData(
      image: 'assets/onboarding/onb-3.png',
      title: 'Разрешите\nгеопозицию',
      subtitle: 'Подставим адрес доставки и проверим, что вы в зоне обслуживания.',
      isLast: true,
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
      HapticFeedback.lightImpact();
    } else {
      widget.onFinish();
    }
  }

  Future<void> _allowLocation() async {
    try {
      await Permission.locationWhenInUse.request();
    } catch (_) {/* не блокируем переход */}
    await _requestNotif();
    widget.onFinish();
  }

  /// Разрешение на уведомления просим в КОНЦЕ онбординга (а не на холодном
  /// старте) — это осмысленный момент: пользователь уже понял, что доставка
  /// присылает статус заказа. На Android < 13 диалога нет (вернётся granted).
  Future<void> _requestNotif() async {
    try {
      await Permission.notification.request();
    } catch (_) {/* не блокируем переход */}
  }

  Future<void> _finishLastPage() async {
    await _requestNotif();
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _beige,
      body: SafeArea(
        child: Column(
          children: [
            // Пропустить (сверху справа).
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: widget.onFinish,
                  child: const Text('Пропустить', style: TextStyle(color: _mute, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _PageView(data: _pages[i]),
              ),
            ),
            // Точки-индикатор.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? _coral : _coral.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            // Кнопки снизу.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _pages[_page].isLast
                  ? Column(
                      children: [
                        _PrimaryButton(label: 'Разрешить геопозицию', onTap: _allowLocation),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _finishLastPage,
                          child: const Text('Не сейчас', style: TextStyle(color: _mute, fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )
                  : _PrimaryButton(label: 'Далее', onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  const _PageData({required this.image, required this.title, required this.subtitle, this.isLast = false});
  final String image;
  final String title;
  final String subtitle;
  final bool isLast;
}

class _PageView extends StatelessWidget {
  const _PageView({required this.data});
  final _PageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Лого-вордмарк bembox.
          const Text('bembox', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, color: _coralDeep)),
          const SizedBox(height: 12),
          // Брендовая иллюстрация экрана.
          Image.asset(data.image, width: 232, height: 232, fit: BoxFit.contain),
          const SizedBox(height: 20),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6, color: _ink),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.4, color: _mute),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_coral, _coralDeep]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33E8551F), blurRadius: 18, spreadRadius: -4, offset: Offset(0, 8))],
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}
