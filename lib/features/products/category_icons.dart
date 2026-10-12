import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Порт `lib/category-icons.ts` + `PCAT_TINT` (1:1 с прод-исходником).
/// Иконка категории берётся ТОЛЬКО из /cat-icons/<slug>.png по whitelist;
/// нет совпадения → null (UI рисует Package-контур). Тинт фона плитки — PCAT_TINT.

const _iconSlugs = <String>{
  'бакалея', 'бальзамы-после-бритья', 'бальзамы', 'бобовые', 'булгур',
  'бумажные-изделия', 'бутылочки', 'бытовая-химия', 'вода-и-напитки', 'вода',
  'газированные-напитки', 'гели-для-купания', 'гигиена-и-косметика', 'гигиена',
  'горох', 'гречка', 'гречневая-каша', 'джемы', 'для-детей', 'капсулы-для-стирки',
  'каши', 'квас', 'кокосовая-мука', 'кондиционеры-для-белья', 'кондиционеры',
  'консервация', 'кормление', 'кремы', 'крупы', 'масла', 'мешки-для-мусора',
  'моющие-средства', 'мыло', 'напитки', 'низкокалорийные-джемы', 'нут',
  'овощные-консервы', 'оливки', 'освежители-воздуха', 'отбеливатели', 'пеленки',
  'пена-для-бритья', 'подгузники', 'прокладки', 'салфетки', 'смеси', 'соки',
  'соски', 'средства-для-мытья-пола', 'средства-для-мытья-посуды', 'стерилизаторы',
  'стиральные-порошки-и-капсулы-для-стирки', 'стиральные-порошки', 'тампоны',
  'томаты', 'уборка', 'уход-за-волосами', 'уход-за-домом', 'уход-за-женским-здоровьем',
  'уход-за-кожей', 'уход', 'фасоль', 'фольга', 'чечевица', 'чистящие-средства', 'шампуни',
};

const _alias = <String, String>{
  'хозтовары': 'бытовая-химия',
  'консервы': 'консервация',
  'консервы и соусы': 'консервация',
  'снеки': 'бакалея',
  'детское питание': 'кормление',
};

const _scoped = <String, List<String>>{
  'масла': ['уход'],
  'уборка': ['бытовая-химия'],
  'каши': ['кормление'],
  'мыло': ['уход'],
  'кремы': ['уход'],
  'смеси': ['кормление'],
};

/// Тинт фона плитки категории (PCAT_TINT). Остальные → #F2EFEA.
const _pcatTint = <String, Color>{
  'Бакалея': Color(0xFFF0E6D6),
  'Вода и напитки': Color(0xFFE4F1FA),
  'Гигиена и косметика': Color(0xFFFBE9F2),
  'Бытовая химия': Color(0xFFE6F4EC),
  'Для детей': Color(0xFFFFF1E0),
  'Хозтовары': Color(0xFFECEAF6),
};

Color categoryTint(String name) => _pcatTint[name] ?? const Color(0xFFF2EFEA);

String _normalize(String name) =>
    name.trim().toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), '-');

/// URL иконки категории или null (тогда UI рисует Package-контур).
String? categoryIconUrl(String? name, {String? parentName}) {
  if (name == null || name.isEmpty) return null;
  final key = _normalize(name);
  final scope = _scoped[key];
  if (scope != null) {
    final pk = parentName != null ? _normalize(parentName) : null;
    if (pk == null || !scope.contains(pk)) return null;
  }
  if (_iconSlugs.contains(key)) {
    return '${AppConfig.siteBaseUrl}/cat-icons/${Uri.encodeComponent(key)}.png';
  }
  final aliased = _alias[key];
  if (aliased != null && _iconSlugs.contains(aliased)) {
    return '${AppConfig.siteBaseUrl}/cat-icons/${Uri.encodeComponent(aliased)}.png';
  }
  return null;
}
