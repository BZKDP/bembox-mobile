import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import 'widgets/address_top_bar.dart';
import 'widgets/sticky_cta_capsule.dart';

/// Маркетплейс — данные 1:1 из `MARKETS` в `app/pvz/page.tsx`.
class _Market {
  const _Market(this.key, this.label, this.full, this.codeLabel, this.example, this.hint, this.logo);
  final String key;
  final String label;
  final String full;
  final String codeLabel;
  final String example;
  final String hint;
  final String logo;
}

const _markets = <_Market>[
  _Market('wb', 'WB', 'Wildberries', 'Код получения', 'WB-4827193',
      'В приложении Wildberries → Доставки → код у пункта выдачи', 'assets/marketplaces/wildberries.webp'),
  _Market('ozon', 'Ozon', 'Ozon', 'Номер отправления', '0123-4567-89',
      'Ozon → Заказы → штрих-код или номер отправления', 'assets/marketplaces/ozon.webp'),
  _Market('ym', 'Маркет', 'Яндекс Маркет', 'Код получения', 'YM-558210',
      'Яндекс Маркет → Мои заказы → код получения из СМС', 'assets/marketplaces/ymarket.webp'),
  _Market('post', 'Почта', 'Почта России', 'Трек-номер', 'RA123456789RU',
      'Почта России → трек-номер из СМС или из приложения', 'assets/marketplaces/pochta.webp'),
];

const _pageBg = Color(0xFFF1EFEB);
const _pvzPrice = 100; // цена доставки посылки (живой сайт)

/// Стеклянная заливка карточек (GLASS на сайте).
BoxDecoration _glass([double radius = 20]) => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      boxShadow: const [BoxShadow(color: Color(0x38281E14), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 12))],
    );

/// Экран «Заберём посылку» (ПВЗ) — порт `app/pvz/page.tsx`, сверен с ЖИВЫМ сайтом.
/// Выбор маркетплейса, ввод кода ИЛИ загрузка фото QR/штрих-кода, инфо где/когда,
/// нижняя кнопка «Заказать доставку».
class PvzScreen extends ConsumerStatefulWidget {
  const PvzScreen({super.key});

  @override
  ConsumerState<PvzScreen> createState() => _PvzScreenState();
}

class _PvzScreenState extends ConsumerState<PvzScreen> {
  String _market = 'wb';
  final _codeCtrl = TextEditingController();
  File? _photo;
  bool _submitting = false;
  bool _done = false;

  _Market get _cur => _markets.firstWhere((m) => m.key == _market);
  bool get _canSubmit => _codeCtrl.text.trim().length >= 4 || _photo != null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: BemColors.coral),
              title: const Text('Сделать фото'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: BemColors.coral),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
    if (x != null && mounted) setState(() => _photo = File(x.path));
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    // Заявка уходит на /api/pvz/attach (подключим к сети на этапе корзины/заказов);
    // сейчас фиксируем результат локально — экран-подтверждение как на сайте.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() { _submitting = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';
    if (_done) return _doneScreen();

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              _hero(address),
              const SizedBox(height: 12),
              // Выбор маркетплейса.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (var i = 0; i < _markets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _marketCard(_markets[i])),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _codeCard(),
              const SizedBox(height: 12),
              _photoCard(),
              const SizedBox(height: 12),
              _infoRow(),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Text(
                  'Получаешь на ${_cur.full}? Укажи адрес ПВЗ bembox при оформлении — заберём и принесём.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, height: 1.35, color: BemColors.mute),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyCtaCapsule(
              show: true,
              title: _submitting ? 'Минутку…' : 'Заказать доставку',
              subtitle: _cur.full,
              price: _pvzPrice,
              onTap: _canSubmit ? _submit : () {},
              disabled: _submitting || !_canSubmit,
            ),
          ),
        ],
      ),
    );
  }

  /// ГЕРОЙ: фон-сцена с посылками + коралловая вуаль, шапка и заголовок поверх.
  Widget _hero(String address) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/pvz/hero-bg.webp', fit: BoxFit.cover, alignment: const Alignment(0, -0.16)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.centerRight,
                colors: [Color(0xF2FFE9E0), Color(0x80FFE9E0), Color(0x00FFE9E0)],
                stops: [0.0, 0.38, 0.62],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x00F1EFEB), Color(0xFFF1EFEB)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AddressTopBar(address: address, backFallback: '/home'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: const Text('Заберём посылку',
                        maxLines: 1,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1, color: BemColors.ink)),
                  ),
                  const SizedBox(height: 8),
                  const Text('с любого маркетплейса — принесём к двери',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: BemColors.ink2)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _marketCard(_Market m) {
    final active = m.key == _market;
    return GestureDetector(
      onTap: () { setState(() => _market = m.key); HapticFeedback.selectionClick(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? BemColors.coral : Colors.white.withValues(alpha: 0.8), width: active ? 1.5 : 1),
          boxShadow: active
              ? [BoxShadow(color: BemColors.coral.withValues(alpha: 0.28), blurRadius: 18, spreadRadius: -8, offset: const Offset(0, 6))]
              : const [BoxShadow(color: Color(0x14000000), blurRadius: 12, spreadRadius: -6, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(m.logo, width: 30, height: 30, fit: BoxFit.cover),
            ),
            const SizedBox(height: 6),
            Text(m.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: -0.2,
                  color: active ? BemColors.coral : BemColors.ink,
                )),
          ],
        ),
      ),
    );
  }

  Widget _codeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _glass(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.inventory_2_outlined, size: 18, color: BemColors.coral),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_cur.codeLabel} · ${_cur.full}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: BemColors.ink)),
                      Text(_cur.hint,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: BemColors.mute)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Поле ввода кода.
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x0F000000)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 20, color: BemColors.coral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: BemColors.ink),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: _cur.example,
                        hintStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, letterSpacing: 1.2, color: BemColors.mute),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Пример: текст слева + фото-подсказка справа.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x0D000000)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ПРИМЕР',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2, color: BemColors.mute)),
                        const SizedBox(height: 3),
                        Text(_cur.example,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: BemColors.ink)),
                        const SizedBox(height: 4),
                        Text(_cur.hint,
                            style: const TextStyle(fontSize: 11, height: 1.3, color: BemColors.mute)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/pvz/qr-help.webp', width: 96, height: 72, fit: BoxFit.cover),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _photo != null
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: _glass(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photo!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Фото кода загружено',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: BemColors.ink)),
                        Text('распознаем сами',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: BemColors.mute)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _photo = null),
                    child: Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(color: Color(0x0D000000), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 18, color: BemColors.ink2),
                    ),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _glass(20),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: const Color(0xFFFFF1EC), borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.upload_outlined, size: 20, color: BemColors.coral),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Загрузить фото QR или штрих-кода',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: BemColors.ink)),
                          Text('Сфоткай код с посылки — распознаем сами',
                              style: TextStyle(fontSize: 11.5, color: BemColors.mute)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoRow() {
    Widget tile(IconData icon, String cap, String text) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _glass(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 16, color: BemColors.coral),
                  const SizedBox(width: 6),
                  Text(cap, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, color: BemColors.mute)),
                ]),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w600, color: BemColors.ink)),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile(Icons.location_on_outlined, 'ГДЕ', 'ул. Игната Титова, 9 — у курьера в подъезде 2'),
            const SizedBox(width: 10),
            tile(Icons.schedule, 'КОГДА', 'Каждый день, с 8 до 22'),
          ],
        ),
      ),
    );
  }

  Widget _doneScreen() {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: BemColors.coralSoft, borderRadius: BorderRadius.circular(26)),
                child: const Icon(Icons.check, size: 38, color: BemColors.coral),
              ),
              const SizedBox(height: 16),
              const Text('Заявка принята',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: BemColors.ink)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.4, color: BemColors.mute),
                  children: [
                    const TextSpan(text: 'Заберём твою посылку '),
                    TextSpan(text: _cur.full, style: const TextStyle(fontWeight: FontWeight.w800, color: BemColors.ink)),
                    _codeCtrl.text.trim().isNotEmpty
                        ? TextSpan(children: [
                            const TextSpan(text: ' по коду '),
                            TextSpan(text: _codeCtrl.text.trim().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: BemColors.ink)),
                          ])
                        : const TextSpan(text: ' по загруженному коду'),
                    const TextSpan(text: ' и принесём к двери.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF7547), Color(0xFFE85522)]),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: Color(0x8CE8551F), blurRadius: 26, spreadRadius: -10, offset: Offset(0, 12))],
                  ),
                  child: const Text('На главную',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
