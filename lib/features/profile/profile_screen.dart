import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../home/widgets/bem_bottom_nav.dart';

const _accountBg = Color(0xFFF6F2EC);
const _coral = BemColors.coral;
const _coralDeep = Color(0xFFE85522);

/// Профиль «Аккаунт» — порт `app/profile/page.tsx`. Шапка, аватар-сосед + имя +
/// телефон, KPI «Заказы», группы «Личные данные / Сервис / Настройки», выход.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String _formatPhone(String? phone) {
    if (phone == null) return '';
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return phone;
    return '+7 (${d.substring(1, 4)}) ${d.substring(4, 7)}-${d.substring(7, 9)}-${d.substring(9, 11)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) (context.canPop() ? context.pop() : context.go('/home')); },
      child: Scaffold(
      backgroundColor: _accountBg,
      extendBody: true,
      bottomNavigationBar: const BemBottomNav(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            _topBar(context),
            if (user == null) _guest(context) else ..._authed(context, ref, user),
          ],
        ),
      ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => SizedBox(
        height: 44,
        child: Stack(alignment: Alignment.center, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : context.go('/home'),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x0F000000))),
                child: const Icon(Icons.chevron_left, size: 22, color: BemColors.ink),
              ),
            ),
          ),
          const Text('Аккаунт', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink)),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _soon(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(width: 38, height: 38, child: Icon(Icons.settings_outlined, size: 21, color: BemColors.ink2)),
            ),
          ),
        ]),
      );

  // ── Гость ──
  Widget _guest(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE6DA), Color(0xFFFFD2BE)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.phone_outlined, size: 28, color: _coral)),
          const SizedBox(height: 16),
          const Text('Войди в bembox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink)),
          const SizedBox(height: 6),
          const Text('По номеру телефона. Никаких карт и регистрации.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: BemColors.ink2)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.push('/login'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.login, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text('Войти', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      );

  // ── Авторизован ──
  List<Widget> _authed(BuildContext context, WidgetRef ref, dynamic user) {
    final phone = _formatPhone(user.phone as String?);
    final name = (user.name as String?)?.trim().isNotEmpty == true ? (user.name as String).trim() : 'Сосед';
    final address = user.lastAddress as String?;
    final email = (() { try { return user.email as String?; } catch (_) { return null; } })();
    return [
      // Аватар + имя + телефон.
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
        child: Column(children: [
          GestureDetector(
            onTap: () => _soon(context),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 104, height: 104,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE9DD), Color(0xFFFFD3C1)]),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x0D000000)),
                ),
                child: CachedNetworkImage(imageUrl: '${AppConfig.siteBaseUrl}/deco/avatar-neighbor.webp', fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, _, _) => const Icon(Icons.person, size: 48, color: _coralDeep)),
              ),
              Positioned(
                bottom: -4, right: -4,
                child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x38000000), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2))]), child: const Icon(Icons.edit, size: 15, color: _coral)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: BemColors.ink)),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(phone, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: BemColors.mute)),
          ],
        ]),
      ),
      // KPI заказы.
      GestureDetector(
        onTap: () => context.push('/orders'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, spreadRadius: -2, offset: Offset(0, 3))]),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF5F4F1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_outlined, size: 18, color: _coral)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('ЗАКАЗЫ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: BemColors.mute)),
              Text('Мои заказы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BemColors.ink)),
            ])),
            const Icon(Icons.chevron_right, color: BemColors.mute),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      _sectionLabel('Личные данные'),
      _group([
        _row(context, Icons.phone_outlined, 'Номер телефона', phone.isEmpty ? 'Добавить номер' : phone, () => _soon(context)),
        _row(context, Icons.mail_outline, 'Почта', email ?? 'Добавить почту', () => _soon(context)),
        _row(context, Icons.location_on_outlined, 'Адрес доставки', address ?? 'Выбрать адрес', () => _soon(context), last: true),
      ]),
      _sectionLabel('Сервис'),
      _group([
        _row(context, Icons.confirmation_num_outlined, null, 'Купоны', () => context.push('/coupons')),
        _row(context, Icons.headset_mic_outlined, null, 'Поддержка и помощник', () => context.push('/support'), last: true),
      ]),
      _sectionLabel('Настройки'),
      _group([
        _row(context, Icons.local_shipping_outlined, null, 'Предпочтения доставки', () => _soon(context)),
        _row(context, Icons.notifications_none, null, 'Уведомления', () => _soon(context)),
        _row(context, Icons.credit_card, null, 'Способы оплаты', () => _soon(context)),
        _row(context, Icons.shield_outlined, null, 'Ваши данные', () => _soon(context)),
        _row(context, Icons.help_outline, null, 'Помощь и информация', () => _soon(context), last: true),
      ]),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () async {
          await ref.read(authControllerProvider.notifier).logout();
          if (context.mounted) context.go('/home');
        },
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, spreadRadius: -2, offset: Offset(0, 3))]),
          child: const Text('Выйти', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFE5342B))),
        ),
      ),
    ];
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: BemColors.ink)),
      );

  Widget _group(List<Widget> rows) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, spreadRadius: -2, offset: Offset(0, 3))]),
        child: Column(children: rows),
      );

  Widget _row(BuildContext context, IconData icon, String? label, String title, VoidCallback onTap, {bool last = false}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1ECE4)))),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFF7F5F1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: _coral)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (label != null) ...[
                Text(label, style: const TextStyle(fontSize: 11, color: BemColors.mute)),
                const SizedBox(height: 1),
              ],
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BemColors.ink)),
            ])),
            const Icon(Icons.chevron_right, size: 18, color: BemColors.mute),
          ]),
        ),
      );

  void _soon(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скоро')));
}
