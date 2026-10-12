import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

/// Купон — порт `Coupon` из `lib/coupon-store.ts`.
class Coupon {
  const Coupon({required this.code, required this.kind, this.phone});
  final String code;
  final String kind; // first-coffee | first-water | first-trash | first-shop | product-suggest
  final String? phone;

  Map<String, dynamic> toJson() => {'code': code, 'kind': kind, if (phone != null) 'phone': phone};
  factory Coupon.fromJson(Map<String, dynamic> j) =>
      Coupon(code: j['code'] as String, kind: j['kind'] as String, phone: j['phone'] as String?);
}

/// Метаданные купонов — 1:1 с `COUPON_META`.
const Map<String, ({String title, String benefit, List<String> scope})> couponMeta = {
  'first-coffee': (title: 'Первый кофе бесплатно', benefit: 'кофе + доставка = 0 ₽', scope: ['coffee']),
  'first-water':  (title: 'Бутылка воды в подарок', benefit: '5 л · доставка = 0 ₽', scope: ['water']),
  'first-trash':  (title: 'Первый вынос мусора',    benefit: 'до 4 пакетов = 0 ₽',  scope: ['trash']),
  'first-shop':   (title: 'Первая доставка продуктов', benefit: 'доставка = 0 ₽',   scope: ['shop']),
  'product-suggest': (title: 'За подсказку товара', benefit: 'скидка 100 ₽',        scope: ['any']),
};

/// coupon-kind → маршрут услуги (куда вести после «Применить»).
String couponRoute(String kind) => switch (kind) {
      'first-coffee' => '/services/coffee',
      'first-water' => '/services/water',
      'first-trash' => '/services/trash',
      'first-shop' => '/services/products',
      _ => '/services/products',
    };

/// service-kind → coupon-kind.
String? couponKindForScope(String scope) => switch (scope) {
      'coffee' => 'first-coffee',
      'water' => 'first-water',
      'trash' => 'first-trash',
      'shop' => 'first-shop',
      _ => null,
    };

bool _scopeMatches(String kind, String scope) {
  final sc = couponMeta[kind]?.scope ?? const [];
  return sc.contains(scope) || sc.contains('any');
}

class CouponState {
  const CouponState({this.coupons = const [], this.appliedCode, this.redeemedByKind = const {}});
  final List<Coupon> coupons;
  /// Применённый купон (одновременно один — как на сайте).
  final String? appliedCode;
  final Map<String, int> redeemedByKind;

  CouponState copyWith({List<Coupon>? coupons, Object? appliedCode = _sentinel, Map<String, int>? redeemedByKind}) =>
      CouponState(
        coupons: coupons ?? this.coupons,
        appliedCode: appliedCode == _sentinel ? this.appliedCode : appliedCode as String?,
        redeemedByKind: redeemedByKind ?? this.redeemedByKind,
      );
  static const _sentinel = Object();
}

/// Купоны — порт `useCoupon` (zustand+persist) на Riverpod. Персист в
/// SharedPreferences под `bemboks-coupon`. На первом запуске молча выдаём 4
/// first-* купона (как `FirstVisitFlow`); applied по умолчанию = первый
/// выпущенный (first-coffee) — ровно как на сайте.
class CouponController extends Notifier<CouponState> {
  static const _key = 'bemboks-coupon';
  static const _issuedFlag = 'bem-coupons-issued';
  // Порядок как в FirstVisitFlow: первый (coffee) станет applied по умолчанию.
  static const _firstSet = ['first-coffee', 'first-trash', 'first-water', 'first-shop'];

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  CouponState build() {
    final s = _load();
    final coupons = [...s.coupons];
    String? applied = s.appliedCode;

    // Первый запуск — выдаём недостающие first-* (как FirstVisitFlow).
    if (_prefs.getBool(_issuedFlag) != true) {
      final existing = coupons.map((c) => c.kind).toSet();
      for (final k in _firstSet) {
        if (!existing.contains(k)) coupons.add(Coupon(code: _genCode(), kind: k));
      }
      _prefs.setBool(_issuedFlag, true);
    }

    // По умолчанию применён first-coffee (как на сайте: issue авто-применяет
    // первый выпущенный). Если кофейного нет — первый из списка.
    if (applied == null && coupons.isNotEmpty) {
      final coffee = coupons.where((c) => c.kind == 'first-coffee').toList();
      applied = coffee.isNotEmpty ? coffee.first.code : coupons.first.code;
    }

    final next = CouponState(coupons: coupons, appliedCode: applied, redeemedByKind: s.redeemedByKind);
    if (next.coupons.length != s.coupons.length || next.appliedCode != s.appliedCode) _persist(next);
    return next;
  }

  CouponState _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const CouponState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final coupons = ((j['coupons'] as List?) ?? const [])
          .map((e) => Coupon.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final redeemed = Map<String, int>.from(
        (j['redeemedByKind'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {},
      );
      return CouponState(coupons: coupons, appliedCode: j['appliedCode'] as String?, redeemedByKind: redeemed);
    } catch (_) {
      return const CouponState();
    }
  }

  void _persist(CouponState s) {
    _prefs.setString(_key, jsonEncode({
      'coupons': [for (final c in s.coupons) c.toJson()],
      'appliedCode': s.appliedCode,
      'redeemedByKind': s.redeemedByKind,
    }));
  }

  /// Применить купон по коду (снимает прошлое применение) — как `apply`.
  void apply(String code) {
    if (state.coupons.any((c) => c.code == code)) {
      state = state.copyWith(appliedCode: code);
      _persist(state);
    }
  }

  /// Применённый купон, если он подходит под область — `getEffectiveCoupon`.
  Coupon? effectiveFor(String scope) {
    final code = state.appliedCode;
    if (code == null) return null;
    for (final c in state.coupons) {
      if (c.code == code) return _scopeMatches(c.kind, scope) ? c : null;
    }
    return null;
  }

  /// Любой купон (применён он или нет), подходящий под область — для подсказки
  /// «Применить купон» на странице услуги.
  Coupon? availableFor(String scope) {
    for (final c in state.coupons) {
      if (_scopeMatches(c.kind, scope)) return c;
    }
    return null;
  }

  /// Погасить купон услуги после оформления (как `markRedeemed`): удаляем,
  /// снимаем применение, считаем в redeemedByKind.
  void redeemScope(String scope) {
    final kind = couponKindForScope(scope);
    if (kind == null) return;
    final idx = state.coupons.indexWhere((c) => c.kind == kind);
    if (idx < 0) return;
    final removed = state.coupons[idx];
    final coupons = [...state.coupons]..removeAt(idx);
    final applied = state.appliedCode == removed.code ? null : state.appliedCode;
    final redeemed = {...state.redeemedByKind, kind: (state.redeemedByKind[kind] ?? 0) + 1};
    state = state.copyWith(coupons: coupons, appliedCode: applied, redeemedByKind: redeemed);
    _persist(state);
  }

  String _genCode() {
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return 'BEM-${List.generate(5, (_) => abc[r.nextInt(abc.length)]).join()}';
  }
}

final couponControllerProvider = NotifierProvider<CouponController, CouponState>(CouponController.new);
