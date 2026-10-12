import '../../core/network/dio_client.dart';
import '../models/product.dart';

/// API каталога товаров (`/api/products/*`).
/// Мобилке отдельный бэкенд не нужен — те же роуты, что у сайта.
class ProductsApi {
  ProductsApi(this._dio);
  final DioClient _dio;

  /// Дерево каталога: `parent == null` → корень (популярное + разделы),
  /// `parent == id` → подкатегории и товары категории.
  Future<Catalog> catalog({String? parent}) async {
    final res = await _dio.get(
      '/products/catalog',
      query: parent == null ? null : {'parent': parent},
    );
    return Catalog.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Поиск товаров. [eta] = '15' | '45' | 'all'. [cat] — uuid категории.
  Future<SearchResult> search({
    String? q,
    String eta = '15',
    String? cat,
    List<String>? ids,
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await _dio.get('/products/search', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      'eta': eta,
      if (cat != null) 'cat': cat,
      if (ids != null && ids.isNotEmpty) 'ids': ids.join(','),
      'limit': limit,
      'offset': offset,
    });
    return SearchResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Полная карточка товара по uuid.
  Future<ProductDetail> product(String id) async {
    final res = await _dio.get('/products/$id');
    return ProductDetail.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
