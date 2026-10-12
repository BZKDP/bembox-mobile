/// Позиция корзины — порт типа `CartProduct` из `apps/web/lib/cart-store.ts` 1:1.
///
/// Корзина общая для товаров магазина и услуг (кофе/вода/мусор/завтрак).
/// Для услуг id синтетический (`svc:trash:1`), а в [service] лежит payload,
/// который потом уходит на бэкенд через `/api/services/order`.
class CartProduct {
  const CartProduct({
    required this.id,
    required this.name,
    this.unit,
    required this.price,
    this.iconEmoji,
    this.shopSlug = '',
    this.kind = 'product',
    this.service,
    this.image,
    this.etaMinutes,
  });

  /// UUID товара, либо синтетический `svc:...` для услуг.
  final String id;
  final String name;

  /// Единица/вес («до 5 кг», «1 л») — может быть null.
  final String? unit;

  /// Цена в РУБЛЯХ целыми (как на бэкенде price).
  final int price;
  final String? iconEmoji;
  final String shopSlug;

  /// 'product' — товар магазина; 'service' — услуга.
  final String kind;

  /// Payload услуги: { kind: 'coffee'|'water'|'trash'|'breakfast', details: {...} }.
  final CartServicePayload? service;

  /// Картинка-превью (для услуг — asset-путь webp).
  final String? image;

  /// Срок доставки в минутах (для услуг — null).
  final int? etaMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'iconEmoji': iconEmoji,
        'shopSlug': shopSlug,
        'kind': kind,
        'service': service?.toJson(),
        'image': image,
        'etaMinutes': etaMinutes,
      };

  factory CartProduct.fromJson(Map<String, dynamic> j) => CartProduct(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String?,
        price: (j['price'] as num).toInt(),
        iconEmoji: j['iconEmoji'] as String?,
        shopSlug: (j['shopSlug'] as String?) ?? '',
        kind: (j['kind'] as String?) ?? 'product',
        service: j['service'] == null
            ? null
            : CartServicePayload.fromJson(Map<String, dynamic>.from(j['service'] as Map)),
        image: j['image'] as String?,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt(),
      );
}

/// Полезная нагрузка услуги в корзине.
class CartServicePayload {
  const CartServicePayload({required this.kind, required this.details});

  /// 'coffee' | 'water' | 'trash' | 'breakfast'.
  final String kind;

  /// Произвольные детали заказа услуги (на бэкенде уходят в orders.comment JSON).
  final Map<String, dynamic> details;

  Map<String, dynamic> toJson() => {'kind': kind, 'details': details};

  factory CartServicePayload.fromJson(Map<String, dynamic> j) => CartServicePayload(
        kind: j['kind'] as String,
        details: Map<String, dynamic>.from((j['details'] as Map?) ?? const {}),
      );
}
