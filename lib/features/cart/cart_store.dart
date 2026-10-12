import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../data/models/cart_item.dart';

/// Иммутабельное состояние корзины — порт `CartState` из cart-store.ts.
class CartState {
  const CartState({this.items = const {}, this.products = const {}});

  /// productId -> qty.
  final Map<String, int> items;

  /// Снимок товаров (чтобы показывать корзину вне страницы магазина).
  final Map<String, CartProduct> products;

  int get totalQty => items.values.fold(0, (s, q) => s + q);

  /// Сумма в РУБЛЯХ (price целые).
  int get totalPrice =>
      items.entries.fold(0, (s, e) => s + (products[e.key]?.price ?? 0) * e.value);

  bool get hasItems => items.isNotEmpty;

  CartState copyWith({Map<String, int>? items, Map<String, CartProduct>? products}) =>
      CartState(items: items ?? this.items, products: products ?? this.products);
}

/// Корзина — порт `useCart` (zustand + persist) на Riverpod.
/// Персист в [SharedPreferences] под ключом `bemboks-cart` (как на вебе).
class CartController extends Notifier<CartState> {
  static const _key = 'bemboks-cart';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  CartState build() => _load();

  CartState _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const CartState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final items = Map<String, int>.from(
        (j['items'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {},
      );
      final products = <String, CartProduct>{};
      (j['products'] as Map?)?.forEach((k, v) {
        products[k as String] = CartProduct.fromJson(Map<String, dynamic>.from(v as Map));
      });
      return CartState(items: items, products: products);
    } catch (_) {
      return const CartState();
    }
  }

  void _persist() {
    final j = {
      'items': state.items,
      'products': state.products.map((k, v) => MapEntry(k, v.toJson())),
    };
    _prefs.setString(_key, jsonEncode(j));
  }

  /// Добавить +1 к позиции (или создать).
  void add(CartProduct p) {
    final qty = (state.items[p.id] ?? 0) + 1;
    state = state.copyWith(
      items: {...state.items, p.id: qty},
      products: {...state.products, p.id: p},
    );
    _persist();
  }

  /// Уменьшить на 1 (на 0 — удалить).
  void remove(String id) {
    final cur = state.items[id] ?? 0;
    if (cur <= 1) {
      setQty(id, 0);
    } else {
      state = state.copyWith(items: {...state.items, id: cur - 1});
      _persist();
    }
  }

  /// Установить точное количество (0 — удалить позицию).
  void setQty(String id, int qty) {
    final items = Map<String, int>.from(state.items);
    final products = Map<String, CartProduct>.from(state.products);
    if (qty <= 0) {
      items.remove(id);
      products.remove(id);
    } else {
      items[id] = qty;
    }
    state = state.copyWith(items: items, products: products);
    _persist();
  }

  void clear() {
    state = const CartState();
    _persist();
  }
}
