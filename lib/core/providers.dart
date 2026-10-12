import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/auth_api.dart';
import '../data/api/geo_api.dart';
import '../data/api/me_api.dart';
import '../data/api/orders_api.dart';
import '../data/api/products_api.dart';
import '../data/models/product.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_state.dart';
import '../features/cart/cart_store.dart';
import 'network/dio_client.dart';
import 'storage/session_store.dart';

/// Центральный реестр зависимостей (Riverpod).
///
/// [secureStorageProvider] и [sessionStoreProvider] переопределяются в `main()`
/// готовыми экземплярами (хранилище создаётся и подгружается ДО запуска UI),
/// поэтому здесь у них «заглушка»-исключение — она никогда не должна сработать.

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => throw UnimplementedError('secureStorageProvider должен быть переопределён в main()'),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('sessionStoreProvider должен быть переопределён в main()'),
);

/// SharedPreferences — для персиста корзины и прочих локальных настроек.
/// Загружается в main() и переопределяется готовым экземпляром.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider должен быть переопределён в main()'),
);

/// Единый HTTP-клиент к API bembox (с auth-интерсептором).
final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(ref.watch(sessionStoreProvider)),
);

/// API-классы по доменам.
final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioClientProvider)));
final meApiProvider = Provider<MeApi>((ref) => MeApi(ref.watch(dioClientProvider)));
final productsApiProvider = Provider<ProductsApi>((ref) => ProductsApi(ref.watch(dioClientProvider)));
final ordersApiProvider = Provider<OrdersApi>((ref) => OrdersApi(ref.watch(dioClientProvider)));
final geoApiProvider = Provider<GeoApi>((ref) => GeoApi(ref.watch(dioClientProvider)));

/// Узел каталога по `parent` (null → корень). Кэшируется по ключу.
final catalogProvider = FutureProvider.family<Catalog, String?>(
  (ref, parent) => ref.watch(productsApiProvider).catalog(parent: parent),
);

/// Полная карточка товара по uuid.
final productDetailProvider = FutureProvider.family<ProductDetail, String>(
  (ref, id) => ref.watch(productsApiProvider).product(id),
);

/// Активные заказы пользователя.
final activeOrdersProvider = FutureProvider.autoDispose<List<OrderSummary>>(
  (ref) => ref.watch(ordersApiProvider).activeOrders(),
);

/// Глобальное состояние авторизации.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Корзина (общая для товаров и услуг).
final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
