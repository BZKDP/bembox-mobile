import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/failures.dart';
import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/api/orders_api.dart';
import '../../data/models/cart_item.dart';
import '../address/map_sheet.dart';
import '../coupons/coupon_store.dart';
import 'cart_store.dart';
import 'yookassa_payment_sheet.dart';

const _pageBg = Color(0xFFFFFCF6);
const _coral = Color(0xFFFF7547);
const _coralDeep = Color(0xFFE85522);
const _divider = Color(0xFFF3ECE4); // border-[#f3ece4]
const _fieldBg = Color(0xFFF8F6F2);
const _segBg = Color(0xFFF4F2EE);
const _green = Color(0xFF16A34A);
const _clearBg = Color(0xFFFFE9E5);
const _clearFg = Color(0xFFE5342B);

/// Экран «Корзина» + оформление — порт `app/cart/page.tsx` (1:1 с сайтом).
/// Один блок «Способ получения» (адрес → кв/подъезд/домофон → комментарий →
/// «оставить у двери» → «когда привезти» + слоты), один блок товаров со
/// строками, оплата, «Итого» в карточке, морфящаяся пилюля «Оформить» и лист
/// подтверждения «Проверьте заказ». Доставка бесплатна. Оплата ЮKassa — позже.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _flat = TextEditingController();
  final _entrance = TextEditingController();
  final _intercom = TextEditingController();
  final _comment = TextEditingController();
  final _scroll = ScrollController();
  bool _leaveAtDoor = true;
  String _when = 'asap'; // asap | scheduled
  String _scheduledTime = '';
  bool _submitting = false;
  bool _paying = false;
  bool _paid = false; // заказ оплачен (0₽/кошелёк) — без редиректа
  bool _expanded = false; // пилюля «Оформить» развёрнута (долистали до низа)
  OrderResult? _placed; // показать экран «Заказ принят»
  int _placedTotal = 0; // сумма оформленного заказа (для кнопки оплаты)

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _flat.dispose();
    _entrance.dispose();
    _intercom.dispose();
    _comment.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Пилюля «Оформить» морфит: компактная справа → широкая внизу, когда
  /// долистали почти до конца длинной корзины (как на сайте).
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final dist = p.maxScrollExtent - p.pixels;
    // Развёрнута на всю ширину, когда корзина почти помещается на экран
    // (скроллить почти нечего) ИЛИ долистали до низа — иначе компактная
    // пилюля наезжает на карточку «Итого».
    final exp = p.maxScrollExtent < 140 || dist < 80;
    if (exp != _expanded) setState(() => _expanded = exp);
  }

  /// Слоты доставки: каждые 15 мин в 08:00–20:00, старт не раньше «сейчас + 30 мин».
  List<String> get _timeSlots {
    const openH = 8, closeH = 20;
    final close = closeH * 60;
    final now = DateTime.now().add(const Duration(minutes: 30));
    final nowTotal = now.hour * 60 + now.minute;
    int h = openH, m = 0;
    if (nowTotal > h * 60 + m) {
      h = now.hour;
      m = (now.minute / 15).ceil() * 15;
      if (m == 60) { h += 1; m = 0; }
    }
    final out = <String>[];
    while (h * 60 + m <= close) {
      out.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      m += 15;
      if (m >= 60) { h += 1; m = 0; }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';
    final entries = cart.items.entries
        .map((e) => (id: e.key, p: cart.products[e.key], qty: e.value))
        .where((e) => e.p != null)
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) (context.canPop() ? context.pop() : context.go('/home')); },
      child: Scaffold(
        backgroundColor: _pageBg,
        body: _placed != null
            ? _success(context)
            : cart.items.isEmpty
                ? _empty(context)
                : _full(context, cart, address, entries),
      ),
    );
  }

  // ─────────────────────────── ПУСТАЯ ───────────────────────────
  Widget _empty(BuildContext context) => SafeArea(
        child: Column(
          children: [
            _appBar(context, showClear: false),
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: _coral.withValues(alpha: 0.4), weight: 300),
                  const SizedBox(height: 16),
                  const Text('Корзина пуста', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: BemColors.ink)),
                  const SizedBox(height: 4),
                  const Text('Закинь что-нибудь — привезём за 15 минут', style: TextStyle(fontSize: 14, color: BemColors.mute)),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/services/products'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(999)),
                      child: const Text('К магазинам', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );

  // ─────────────────────────── ПОЛНАЯ ───────────────────────────
  Widget _full(BuildContext context, CartState cart, String address,
      List<({String id, CartProduct? p, int qty})> entries) {
    final total = cart.totalPrice;
    final qty = cart.totalQty;
    final hasExtra = _flat.text.trim().isNotEmpty || _entrance.text.trim().isNotEmpty || _intercom.text.trim().isNotEmpty;

    // Пересчитать состояние пилюли после раскладки: для короткой корзины
    // слушатель скролла сам не сработает (скроллить нечего).
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _onScroll(); });

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              _appBar(context, showClear: true, pad: false),

              // ── СПОСОБ ПОЛУЧЕНИЯ — один блок с разделителями ──
              _sectionLabel('Способ получения'),
              _whiteCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  // Адрес.
                  _rowButton(
                    onTap: () => showAddressMapSheet(context, ref),
                    child: Row(children: [
                      _iconBox(Icons.local_shipping_outlined, const Color(0xFFF5F4F1)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Курьером по адресу', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BemColors.ink)),
                        const SizedBox(height: 2),
                        Text(address.isEmpty ? 'ул. Игната Титова, 9' : address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: BemColors.mute)),
                        if (hasExtra) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (_flat.text.trim().isNotEmpty) 'кв. ${_flat.text.trim()}',
                              if (_entrance.text.trim().isNotEmpty) 'под. ${_entrance.text.trim()}',
                              if (_intercom.text.trim().isNotEmpty) 'домофон ${_intercom.text.trim()}',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11.5, color: _green),
                          ),
                        ],
                      ])),
                      const Icon(Icons.chevron_right, size: 18, color: BemColors.mute),
                    ]),
                  ),
                  _dividerLine(),
                  // Квартира / подъезд / домофон.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _miniField(_flat, 'Квартира', '12', numeric: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _miniField(_entrance, 'Подъезд', '2', numeric: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _miniField(_intercom, 'Домофон', '9К1234')),
                    ]),
                  ),
                  _dividerLine(),
                  // Комментарий.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.chat_bubble_outline, size: 17, color: _coral),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: _comment,
                        maxLength: 500,
                        style: const TextStyle(fontSize: 13.5, color: BemColors.ink),
                        decoration: const InputDecoration(filled: false, counterText: '', isCollapsed: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: 'Комментарий курьеру', hintStyle: TextStyle(fontSize: 13.5, color: BemColors.mute)),
                      )),
                    ]),
                  ),
                  _dividerLine(),
                  // Оставить у двери.
                  _rowButton(
                    onTap: () => setState(() => _leaveAtDoor = !_leaveAtDoor),
                    child: Row(children: [
                      const Icon(Icons.meeting_room_outlined, size: 17, color: _coral),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Оставить у двери', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: BemColors.ink))),
                      _doorSwitch(_leaveAtDoor),
                    ]),
                  ),
                  _dividerLine(),
                  // Когда привезти.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.schedule, size: 17, color: _coral),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Когда привезти', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: BemColors.ink))),
                      _whenSeg(),
                    ]),
                  ),
                  if (_when == 'scheduled') ...[
                    _dividerLine(),
                    _timeSlotsRow(),
                  ],
                ]),
              ),

              // ── В ЗАКАЗЕ ──
              _sectionLabel('В заказе · $qty'),
              _whiteCard(
                padding: const EdgeInsets.all(6),
                child: _itemsList(entries),
              ),

              // ── ДОБАВИТЬ ЕЩЁ ──
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/services/products'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0D9CB), width: 1.5, style: BorderStyle.solid),
                  ),
                  alignment: Alignment.center,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 14, color: _coralDeep),
                    SizedBox(width: 8),
                    Text('Добавить ещё', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _coralDeep)),
                  ]),
                ),
              ),

              // ── ОПЛАТА ──
              _sectionLabel('Оплата'),
              _whiteCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  _iconBox(Icons.credit_card, const Color(0xFFFFF1EC)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Онлайн картой', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BemColors.ink)),
                    SizedBox(height: 2),
                    Text('Безопасно через эквайринг — после нажатия на «Оформить»', style: TextStyle(fontSize: 12, color: BemColors.mute)),
                  ])),
                  const SizedBox(width: 8),
                  Container(width: 22, height: 22, decoration: const BoxDecoration(color: _coral, shape: BoxShape.circle), child: const Icon(Icons.check, size: 13, color: Colors.white)),
                ]),
              ),

              // ── ИТОГО ──
              _sectionLabel(''),
              _whiteCard(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Итого', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BemColors.ink)),
                    const SizedBox(height: 2),
                    Text('$qty ${qty == 1 ? 'товар' : 'позиций'} · доставим за 15 мин', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BemColors.mute)),
                  ])),
                  Text('$total ₽', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: BemColors.ink)),
                ]),
              ),
            ],
          ),

          // ── МОРФЯЩАЯСЯ ПИЛЮЛЯ «ОФОРМИТЬ» ──
          _checkoutPill(context, total),
        ],
      ),
    );
  }

  // ─────────────────────────── ПИЛЮЛЯ CTA ───────────────────────────
  Widget _checkoutPill(BuildContext context, int total) {
    return Positioned(
      left: 0, right: 0, bottom: 14,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _expanded ? 16 : 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _submitting ? null : () => _openConfirm(context, total),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 360),
              curve: const Cubic(0.22, 0.68, 0.32, 1),
              width: _expanded ? double.infinity : null,
              height: _expanded ? 56 : 44,
              padding: EdgeInsets.only(left: _expanded ? 20 : 14, right: _expanded ? 20 : 6),
              decoration: BoxDecoration(
                color: _coral,
                borderRadius: BorderRadius.circular(_expanded ? 18 : 999),
                boxShadow: [
                  BoxShadow(color: _coral.withValues(alpha: 0.55), blurRadius: _expanded ? 32 : 24, spreadRadius: _expanded ? -10 : -8, offset: Offset(0, _expanded ? 14 : 10)),
                  if (!_expanded) const BoxShadow(color: Color(0x8CFFFFFF), spreadRadius: 1.5),
                ],
              ),
              child: Row(
                mainAxisSize: _expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: _expanded ? MainAxisAlignment.center : MainAxisAlignment.end,
                children: [
                  if (_submitting)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  else ...[
                    if (_expanded) ...[
                      Text(total <= 0 ? 'Получить бесплатно' : 'Оформить заказ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white)),
                      if (total > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('·', style: TextStyle(color: Color(0x80FFFFFF), fontSize: 16))),
                    ],
                    Text('$total ₽', style: TextStyle(fontSize: _expanded ? 16 : 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (!_expanded) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                        child: const Icon(Icons.shopping_bag_outlined, size: 15, color: Colors.white),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── ЛИСТ ПОДТВЕРЖДЕНИЯ ───────────────────────────
  void _openConfirm(BuildContext context, int total) {
    final address = ref.read(authControllerProvider).user?.lastAddress ?? '';
    final qty = ref.read(cartControllerProvider).totalQty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x59000000),
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0x1A000000), borderRadius: BorderRadius.circular(999)))),
          const Padding(padding: EdgeInsets.only(left: 4, bottom: 12), child: Text('Проверьте заказ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink))),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: const Color(0xFFF7F5F1), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _confirmRow('Куда', address.isEmpty ? 'ул. Игната Титова, 9' : address),
              _confirmRow('Оплата', 'Онлайн картой'),
              if (_leaveAtDoor) _confirmRow('Курьеру', 'Оставить у двери'),
              _confirmRow('Позиций', '$qty'),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x14000000)))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Итого', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BemColors.ink)),
                  Text('$total ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BemColors.ink)),
                ]),
              ),
            ]),
          ),
          GestureDetector(
            onTap: () { Navigator.of(ctx).pop(); _checkout(context); },
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_coral, _coralDeep]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x99E8551F), blurRadius: 24, spreadRadius: -10, offset: Offset(0, 10))],
              ),
              child: Text('Подтвердить · $total ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('Назад', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BemColors.mute)))),
          ),
        ]),
      ),
    );
  }

  Widget _confirmRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BemColors.mute)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BemColors.ink))),
        ]),
      );

  // ─────────────────────────── ТОВАРЫ ───────────────────────────
  Widget _itemsList(List<({String id, CartProduct? p, int qty})> entries) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      rows.add(_item(entries[i].id, entries[i].p!, entries[i].qty, divider: i > 0));
    }
    final col = Column(children: rows);
    if (entries.length > 4) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 4 * 72 + 12),
        child: SingleChildScrollView(child: col),
      );
    }
    return col;
  }

  Widget _item(String id, CartProduct p, int qty, {required bool divider}) {
    final notifier = ref.read(cartControllerProvider.notifier);
    final isFree = id.endsWith(':free');
    final isTrash = id.startsWith('svc:trash:');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: _divider))) : null,
      child: Row(children: [
        Container(
          width: 48, height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _img(p.image)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: BemColors.ink))),
            if (isFree) Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_coral, Color(0xFFF0581F)]), borderRadius: BorderRadius.circular(6)),
              child: const Text('купон', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 2),
          isFree
              ? const Text('1 шт по купону · бесплатно', style: TextStyle(fontSize: 11, color: _green))
              : Text('${p.unit ?? 'шт'} · ${p.price} ₽/шт', style: const TextStyle(fontSize: 11, color: BemColors.mute)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${p.price * qty} ₽', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BemColors.ink)),
          const SizedBox(height: 6),
          if (isFree || isTrash)
            GestureDetector(
              onTap: () => notifier.remove(p.id),
              child: const Text('Убрать', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BemColors.mute, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted)),
            )
          else
            Container(
              decoration: BoxDecoration(color: _segBg, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _stepBtn(Icons.remove, BemColors.ink, () => notifier.remove(p.id)),
                SizedBox(width: 18, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: BemColors.ink))),
                _stepBtn(Icons.add, _coral, () => notifier.add(p)),
              ]),
            ),
        ]),
      ]),
    );
  }

  Widget _img(String? image) {
    if (image == null) return const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.image_outlined, size: 18, color: BemColors.mute));
    if (image.startsWith('assets/')) return Image.asset(image, fit: BoxFit.contain);
    return CachedNetworkImage(imageUrl: image, fit: BoxFit.contain, placeholder: (_, _) => const ColoredBox(color: Color(0xFFF1F1F1)), errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.image_outlined, size: 18, color: BemColors.mute)));
  }

  Widget _stepBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 13, color: color)));

  // ─────────────────────────── ОФОРМЛЕНИЕ ───────────────────────────
  Future<void> _checkout(BuildContext context) async {
    if (_submitting) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthed) {
      context.push('/login');
      return;
    }
    final cart = ref.read(cartControllerProvider);
    final address = auth.user?.lastAddress ?? '';
    final phone = auth.user?.phone ?? '';
    final fullComment = [
      _comment.text.trim(),
      _leaveAtDoor ? 'Оставить у двери' : '',
      _when == 'scheduled' && _scheduledTime.isNotEmpty ? 'К $_scheduledTime' : '',
    ].where((s) => s.isNotEmpty).join(' · ');
    final extra = {
      if (_flat.text.trim().isNotEmpty) 'flat': _flat.text.trim(),
      if (_entrance.text.trim().isNotEmpty) 'entrance': _entrance.text.trim(),
      if (_intercom.text.trim().isNotEmpty) 'intercom': _intercom.text.trim(),
    };

    setState(() => _submitting = true);
    try {
      final api = ref.read(ordersApiProvider);
      final serviceLines = cart.items.entries.where((e) => cart.products[e.key]?.kind == 'service').toList();
      final productLines = cart.items.entries.where((e) => cart.products[e.key]?.kind != 'service').toList();
      OrderResult? last;

      if (serviceLines.isNotEmpty) {
        final first = cart.products[serviceLines.first.key]!;
        final svcKind = first.service?.kind ?? 'coffee';
        final lineItems = [
          for (final e in serviceLines)
            {'label': cart.products[e.key]!.name, 'qty': e.value, 'unitPrice': cart.products[e.key]!.price, ...?cart.products[e.key]!.service?.details},
        ];
        final itemsTotal = serviceLines.fold<int>(0, (s, e) => s + (cart.products[e.key]!.price) * e.value);
        last = await api.createServiceOrder(
          kind: svcKind, phone: phone, address: address,
          details: {
            ...?first.service?.details,
            'items': lineItems, 'count': lineItems.length, 'fromCart': true,
            ...extra,
            if (fullComment.isNotEmpty) 'comment': fullComment,
            'when': _when, 'leaveAtDoor': _leaveAtDoor,
            if (_when == 'scheduled' && _scheduledTime.isNotEmpty) 'whenTime': _scheduledTime,
          },
          total: itemsTotal, itemsTotal: itemsTotal,
        );
      }
      if (productLines.isNotEmpty) {
        last = await api.createProductOrder(
          items: [for (final e in productLines) (productId: e.key, qty: e.value)],
          comment: fullComment.isNotEmpty ? fullComment : null,
          addressOverride: {
            'label': 'Дом',
            'address': address.isNotEmpty ? address : 'ул. Игната Титова, 9',
            'lat': 55.6745,
            'lng': 37.2585,
            ...extra,
          },
        );
      }
      if (!mounted) return;
      final paidTotal = cart.totalPrice;
      // Погасить купоны за бесплатные (:free) позиции.
      for (final e in cart.items.entries) {
        if (e.key.endsWith(':free')) {
          final kind = cart.products[e.key]?.service?.kind;
          if (kind != null) ref.read(couponControllerProvider.notifier).redeemScope(kind);
        }
      }
      ref.read(cartControllerProvider.notifier).clear();
      setState(() { _submitting = false; _placed = last; _placedTotal = paidTotal; });
    } on AppFailure catch (f) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось оформить заказ')));
      }
    }
  }

  /// Оплата картой: POST /orders/{id}/pay → открыть страницу ЮKassa
  /// (confirmationUrl) во внешнем браузере. Реальную оплату завершает юзер.
  Future<void> _pay() async {
    final placed = _placed;
    if (placed == null || _paying) return;
    setState(() => _paying = true);
    try {
      final r = await ref.read(ordersApiProvider).payOrder(placed.id, method: 'card');
      if (r.kind == 'embedded' && r.confirmationToken != null) {
        // Встроенный виджет ЮKassa (как на сайте) в WebView.
        if (!mounted) return;
        final ok = await showYookassaPayment(context, confirmationToken: r.confirmationToken!, orderId: placed.id);
        if (ok && mounted) setState(() => _paid = true);
      } else if (r.kind == 'redirect' && r.confirmationUrl != null) {
        await launchUrl(Uri.parse(r.confirmationUrl!), mode: LaunchMode.externalApplication);
      } else if (r.kind == 'paid') {
        if (mounted) setState(() => _paid = true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть оплату — попробуйте ещё раз')));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  // ─────────────────────────── УСПЕХ ───────────────────────────
  Widget _success(BuildContext context) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(color: BemColors.coralSoft, borderRadius: BorderRadius.circular(28)),
                  child: Icon(_paid ? Icons.check_rounded : Icons.receipt_long_rounded, size: 42, color: _coral),
                ),
                const SizedBox(height: 18),
                Text(_paid ? 'Заказ оплачен' : 'Заказ оформлен', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: BemColors.ink)),
                const SizedBox(height: 8),
                Text('Заказ ${_placed!.number}  ·  привезём за 15 минут', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: BemColors.mute)),
                const SizedBox(height: 6),
                Text(_paid ? 'Спасибо! Уже собираем.' : 'Осталось оплатить — откроется защищённая страница банка', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: BemColors.mute)),
                const SizedBox(height: 24),
                if (!_paid)
                  GestureDetector(
                    onTap: _paying ? null : _pay,
                    child: Container(
                      height: 54,
                      width: 260,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_coral, _coralDeep]),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x80E8551F), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 10))],
                      ),
                      child: _paying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.credit_card, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(_placedTotal > 0 ? 'Оплатить картой · $_placedTotal ₽' : 'Оплатить картой', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                            ]),
                    ),
                  ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => context.go('/orders'),
                  child: const Padding(padding: EdgeInsets.all(8), child: Text('Мои заказы', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BemColors.mute))),
                ),
              ],
            ),
          ),
        ),
      );

  // ─────────────────────────── ОБЩИЕ ВИДЖЕТЫ ───────────────────────────
  Widget _appBar(BuildContext context, {required bool showClear, bool pad = true}) => Padding(
        padding: EdgeInsets.fromLTRB(pad ? 8 : 0, 6, 0, 6),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
            behavior: HitTestBehavior.opaque,
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.chevron_left, color: BemColors.ink)),
          ),
          const SizedBox(width: 2),
          const Expanded(child: Text('Корзина', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink))),
          if (showClear)
            GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    content: const Text('Очистить корзину?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Очистить', style: TextStyle(color: _clearFg, fontWeight: FontWeight.w800))),
                    ],
                  ),
                );
                if (ok == true) { ref.read(cartControllerProvider.notifier).clear(); HapticFeedback.mediumImpact(); }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _clearBg, borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_outline, size: 14, color: _clearFg),
                  SizedBox(width: 5),
                  Text('Очистить', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _clearFg)),
                ]),
              ),
            ),
        ]),
      );

  Widget _whenSeg() {
    Widget seg(String v, String label) {
      final on = _when == v;
      return GestureDetector(
        onTap: () => setState(() => _when = v),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? _coral : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: on ? const [BoxShadow(color: Color(0x80E8551F), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2))] : null,
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : const Color(0xFF7A6F66))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _segBg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('asap', 'За 15 мин'), seg('scheduled', 'Ко времени')]),
    );
  }

  Widget _timeSlotsRow() {
    final slots = _timeSlots;
    if (_scheduledTime.isEmpty && slots.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scheduledTime.isEmpty) setState(() => _scheduledTime = slots.first);
      });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 29),
          const Expanded(child: Text('К скольки', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BemColors.ink))),
          Text(_scheduledTime.isEmpty ? '—' : _scheduledTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _coral)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: slots.isEmpty
              ? const Text('Сегодня уже поздно — попробуйте завтра, приём с 8:00.', style: TextStyle(fontSize: 12, color: BemColors.mute))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: slots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final t = slots[i];
                    final on = t == _scheduledTime;
                    return GestureDetector(
                      onTap: () => setState(() => _scheduledTime = t),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? _coral : _segBg,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: on ? const [BoxShadow(color: Color(0x8CE8551F), blurRadius: 12, spreadRadius: -4, offset: Offset(0, 4))] : null,
                        ),
                        child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? Colors.white : const Color(0xFF5C5048))),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _doorSwitch(bool on) => GestureDetector(
        onTap: () => setState(() => _leaveAtDoor = !_leaveAtDoor),
        child: Container(
          width: 42, height: 24,
          decoration: BoxDecoration(color: on ? _coral : const Color(0xFFE3DED5), borderRadius: BorderRadius.circular(999)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18, height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))]),
            ),
          ),
        ),
      );

  Widget _miniField(TextEditingController c, String label, String hint, {bool numeric = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // label: 10px/700, mute, letterSpacing 0.5, mb4 (с живого DOM).
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: BemColors.mute)),
          const SizedBox(height: 4),
          // bg #F8F6F2, radius РОВНО 8px, inset 1px rgba(0,0,0,0.05), текст слева.
          Container(
            height: 34,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x0D000000)),
            ),
            child: TextField(
              controller: c,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              textAlign: TextAlign.left,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: _coral,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: BemColors.ink),
              decoration: InputDecoration(
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: BemColors.mute),
              ),
            ),
          ),
        ],
      );

  Widget _sectionLabel(String t) => Padding(
        padding: EdgeInsets.fromLTRB(4, t.isEmpty ? 10 : 16, 4, t.isEmpty ? 0 : 6),
        child: t.isEmpty ? const SizedBox.shrink() : Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: BemColors.mute)),
      );

  Widget _whiteCard({required Widget child, required EdgeInsets padding}) => Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2))]),
        child: child,
      );

  Widget _rowButton({required Widget child, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), child: child),
      );

  Widget _dividerLine() => const Divider(height: 1, thickness: 1, color: _divider);

  Widget _iconBox(IconData icon, Color bg) => Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 17, color: _coral));
}
