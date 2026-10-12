import '../../core/config/app_config.dart';

/// Товар каталога — порт `ApiProduct` (`lib/products-api.ts`) + поля из
/// `/api/products/catalog`. Цена в РУБЛЯХ целыми.
class ApiProduct {
  const ApiProduct({
    required this.id,
    required this.name,
    this.brand,
    required this.price,
    this.oldPrice,
    this.unit,
    this.image,
    this.etaMinutes = 15,
    this.ratingAvg,
    this.category,
  });

  final String id;
  final String name;
  final String? brand;
  final int price;
  final int? oldPrice;
  final String? unit;

  /// Относительный путь картинки на сайте (`/products/own/...jpg`).
  final String? image;
  final int etaMinutes;
  final double? ratingAvg;

  /// UUID категории (для подбора «похожих»).
  final String? category;

  /// Полный URL картинки (бэкенд отдаёт путь от корня сайта, не от /api).
  String? get imageUrl {
    final i = image;
    if (i == null || i.isEmpty) return null;
    if (i.startsWith('http')) return i;
    return '${AppConfig.siteBaseUrl}$i';
  }

  factory ApiProduct.fromJson(Map<String, dynamic> j) => ApiProduct(
        id: j['id'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String?,
        price: (j['price'] as num).toInt(),
        oldPrice: (j['oldPrice'] as num?)?.toInt(),
        unit: j['unit'] as String?,
        image: j['image'] as String?,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt() ?? 15,
        ratingAvg: (j['ratingAvg'] as num?)?.toDouble(),
        category: (j['category'] ?? j['categoryId']) as String?,
      );
}

/// КБЖУ на 100 г (ключи API: *_100g).
class Kbju {
  const Kbju({this.kcal, this.protein, this.fat, this.carb});
  final double? kcal, protein, fat, carb;

  bool get hasAny => (kcal ?? 0) > 0 || (protein ?? 0) > 0 || (fat ?? 0) > 0 || (carb ?? 0) > 0;

  static Kbju? fromJson(dynamic j) {
    if (j is! Map) return null;
    double? n(String k) => (j[k] as num?)?.toDouble();
    return Kbju(
      kcal: n('energy_kcal_100g') ?? n('kcal'),
      protein: n('proteins_100g') ?? n('protein'),
      fat: n('fat_100g') ?? n('fat'),
      carb: n('carbohydrates_100g') ?? n('carb'),
    );
  }
}

/// Полная карточка товара — ответ `/api/products/[id]`.
class ProductDetail extends ApiProduct {
  const ProductDetail({
    required super.id,
    required super.name,
    super.brand,
    required super.price,
    super.oldPrice,
    super.unit,
    super.image,
    super.etaMinutes,
    super.ratingAvg,
    super.category,
    this.source,
    this.composition,
    this.description,
    this.shelfLife,
    this.kbju,
  });

  final String? source;
  final String? composition;
  final String? description;
  final String? shelfLife;
  final Kbju? kbju;

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        id: j['id'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String?,
        price: (j['price'] as num).toInt(),
        oldPrice: (j['oldPrice'] as num?)?.toInt(),
        unit: j['unit'] as String?,
        image: j['image'] as String?,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt() ?? 15,
        ratingAvg: (j['ratingAvg'] as num?)?.toDouble(),
        category: (j['category'] ?? j['categoryId']) as String?,
        source: j['source'] as String?,
        composition: (j['composition'] as String?)?.trim(),
        description: (j['description'] as String?)?.trim(),
        shelfLife: (j['shelfLife'] as String?)?.trim(),
        kbju: Kbju.fromJson(j['kbju']),
      );
}

/// Результат поиска `/api/products/search`.
class SearchResult {
  const SearchResult({this.items = const [], this.total = 0, this.hasMore = false, this.suggestion});
  final List<ApiProduct> items;
  final int total;
  final bool hasMore;
  final String? suggestion; // did-you-mean label

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        hasMore: j['hasMore'] == true,
        suggestion: j['suggestion'] is Map ? (j['suggestion']['label'] as String?) : null,
      );
}

/// Категория закупки (`purchase_categories`) из дерева каталога.
class PCat {
  const PCat({required this.id, required this.name, required this.level, required this.count});
  final String id;
  final String name;
  final int level;
  final int count;

  factory PCat.fromJson(Map<String, dynamic> j) => PCat(
        id: j['id'] as String,
        name: j['name'] as String,
        level: (j['level'] as num?)?.toInt() ?? 1,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// Ответ `/api/products/catalog` — узел дерева категорий + товары на остатке.
class Catalog {
  const Catalog({this.parent, this.breadcrumb = const [], this.subcats = const [], this.products = const []});
  final String? parent;
  final List<({String id, String name})> breadcrumb;
  final List<PCat> subcats;
  final List<ApiProduct> products;

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        parent: j['parent'] as String?,
        breadcrumb: ((j['breadcrumb'] as List?) ?? const [])
            .map((e) => (id: e['id'] as String, name: e['name'] as String))
            .toList(),
        subcats: ((j['subcats'] as List?) ?? const [])
            .map((e) => PCat.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        products: ((j['products'] as List?) ?? const [])
            .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
