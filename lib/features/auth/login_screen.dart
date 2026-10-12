import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failures.dart';
import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../core/theme/bem_radii.dart';
import '../../core/theme/bem_text_styles.dart';
import '../../core/utils/phone.dart';

/// Экран входа по SMS — порт `apps/web/app/login/page.tsx` 1:1
/// (те же шаги, тексты, размеры и логика запросов).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// Шаги экрана — как `type Step = 'phone' | 'code' | 'done'` на сайте.
enum _Step { phone, code, done }

/// Тень `shadow-bem-coral` из tailwind: 0 12px 22px -10px rgba(255,117,71,.45).
const _coralShadow = BoxShadow(
  color: Color(0x73FF7547),
  blurRadius: 22,
  spreadRadius: -10,
  offset: Offset(0, 12),
);

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Step _step = _Step.phone;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _submitting = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  String get _phone => _phoneCtrl.text;
  bool get _phoneValid => Phone.isValid(_phone);
  bool get _codeValid => RegExp(r'^\d{6}$').hasMatch(_codeCtrl.text);

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendIn = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _resendIn--;
        if (_resendIn <= 0) t.cancel();
      });
    });
  }

  /// Шаг 1 — отправить код.
  Future<void> _sendCode() async {
    if (!_phoneValid) {
      setState(() => _error = 'Введи 11 цифр номера');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).sendSmsCode(_phone);
      if (!mounted) return;
      setState(() => _step = _Step.code);
      _startResendCountdown();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Шаг 2 — проверить код, создать сессию.
  Future<void> _verifyCode() async {
    if (!_codeValid) {
      setState(() => _error = 'Код — 6 цифр');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).verifySmsCode(_phone, _codeCtrl.text);
      // cookie уже сохранена интерсептором — подтягиваем профиль.
      await ref.read(authControllerProvider.notifier).onLoggedIn();
      if (!mounted) return;
      setState(() => _step = _Step.done);
      // Небольшая пауза, чтобы пользователь увидел «Готово», затем на главную.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) context.go('/home');
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BemColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: switch (_step) {
                      _Step.phone => _phoneStep(),
                      _Step.code => _codeStep(),
                      _Step.done => _doneStep(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Шапка: кнопка «назад» + заголовок «Вход».
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _BackArrowBox(onTap: () => context.canPop() ? context.pop() : context.go('/home')),
          const SizedBox(width: 8),
          Text('Вход', style: BemText.h3.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Шаг 1: телефон ──
  Widget _phoneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _coralIcon(Icons.phone),
        const SizedBox(height: 20),
        Text('Войти по номеру', textAlign: TextAlign.center, style: _title()),
        const SizedBox(height: 8),
        _subtitle('Пришлём код в SMS для входа.'),
        const SizedBox(height: 24),
        // Поле телефона — pill-soft, иконка + tel-инпут с маской.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0x0B000000), // .pill-soft = rgba(0,0,0,.045)
              borderRadius: BemRadii.rXl,
            ),
            child: Row(
              children: [
                const Icon(Icons.phone, size: 18, color: BemColors.mute),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    inputFormatters: [_PhoneMaskFormatter()],
                    onChanged: (_) => setState(() => _error = null),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      hintText: '+7 (___) ___-__-__',
                    ),
                    style: BemText.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) _errorText(_error!),
        _coralButton(
          label: _submitting ? 'Отправляем…' : 'Получить код',
          trailing: Icons.chevron_right,
          enabled: _phoneValid && !_submitting,
          onTap: _sendCode,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Нажимая «Получить код», ты соглашаешься с условиями. Мы сохраним номер только в твоём профиле.',
            textAlign: TextAlign.center,
            style: BemText.caption.copyWith(fontSize: 10.5, height: 1.35),
          ),
        ),
      ],
    );
  }

  // ── Шаг 2: код ──
  Widget _codeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _coralIcon(Icons.phone),
        const SizedBox(height: 20),
        Text('Код из SMS', textAlign: TextAlign.center, style: _title()),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text.rich(
            TextSpan(
              style: BemText.small.copyWith(color: BemColors.mute, fontSize: 13),
              children: [
                TextSpan(text: 'Отправили на $_phone. '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _step = _Step.phone;
                      _error = null;
                    }),
                    child: Text('Изменить',
                        style: BemText.small.copyWith(
                            color: BemColors.coral, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0x0B000000),
              borderRadius: BemRadii.rXl,
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _verifyCode(),
              decoration: const InputDecoration(
                isCollapsed: true,
                filled: false,
                counterText: '',
                border: InputBorder.none,
                hintText: '••••••',
              ),
              style: BemText.h2.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) _errorText(_error!),
        _coralButton(
          label: _submitting ? 'Проверяем…' : 'Войти',
          enabled: _codeValid && !_submitting,
          onTap: _verifyCode,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: (_resendIn > 0 || _submitting) ? null : _sendCode,
          child: Text(
            _resendIn > 0 ? 'Отправить ещё раз через $_resendIn сек' : 'Отправить код ещё раз',
            style: BemText.small.copyWith(
              color: BemColors.mute,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  // ── Шаг 3: готово ──
  Widget _doneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: BemColors.coralSoft, borderRadius: BemRadii.rXl2),
          child: const Icon(Icons.check, size: 28, color: BemColors.coral, weight: 900),
        ),
        const SizedBox(height: 20),
        Text('Готово', textAlign: TextAlign.center, style: _title()),
        const SizedBox(height: 8),
        _subtitle('Добро пожаловать в bembox. Открываю профиль…'),
      ],
    );
  }

  // ── Мелкие переиспользуемые куски ──
  TextStyle _title() =>
      BemText.h2.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.1);

  Widget _subtitle(String text) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Text(text,
            textAlign: TextAlign.center,
            style: BemText.small.copyWith(color: BemColors.mute, fontSize: 13)),
      );

  Widget _coralIcon(IconData icon) => Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: BemColors.coral,
          borderRadius: BemRadii.rXl2, // 32 на 64 = круг
          boxShadow: [_coralShadow],
        ),
        child: Icon(icon, size: 26, color: Colors.white),
      );

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5)),
      );

  /// Кнопка `.bg-coral rounded-full py-4 font-extrabold text-[16px]` с тенью.
  Widget _coralButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SizedBox(
        width: double.infinity,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BemRadii.rFull,
              boxShadow: [_coralShadow],
            ),
            child: ElevatedButton(
              onPressed: enabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: BemColors.coral,
                disabledBackgroundColor: BemColors.coral,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(borderRadius: BemRadii.rFull),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    Icon(trailing, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Квадратная кнопка «назад» со стрелкой — как `<BackArrowBox/>` на сайте
/// (белый квадрат со скруглением и лёгкой тенью).
class _BackArrowBox extends StatelessWidget {
  const _BackArrowBox({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BemRadii.rFull,
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.chevron_left, size: 24, color: BemColors.ink),
      ),
    );
  }
}

/// Маска ввода телефона `+7 (XXX) XXX-XX-XX` — использует [Phone.format] (порт
/// логики сайта), курсор держим в конце.
class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = Phone.format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
