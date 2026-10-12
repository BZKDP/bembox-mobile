import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/auth_state.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/products/favorites_screen.dart';
import '../features/products/product_category_screen.dart';
import '../features/products/product_detail_screen.dart';
import '../features/products/product_search_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/coupons/coupons_screen.dart';
import '../features/chat/assistant_screen.dart';
import '../features/chat/support_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/products/products_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/services/breakfast_screen.dart';
import '../features/services/coffee_screen.dart';
import '../features/services/pvz_screen.dart';
import '../features/services/trash_screen.dart';
import '../features/services/water_screen.dart';
import '../features/splash/splash_screen.dart';

/// Пути приложения в одном месте — чтобы не плодить строки-магии по коду.
abstract final class Routes {
  static const splash = '/splash';
  static const home = '/home';
  static const login = '/login';
  static const profile = '/profile';
  static const servicesTrash = '/services/trash';
  static const servicesCoffee = '/services/coffee';
  static const servicesBreakfast = '/services/breakfast';
  static const servicesWater = '/services/water';
  static const servicesProducts = '/services/products';
  static const pvz = '/pvz';
}

/// Роуты, требующие входа. Гость при попытке зайти → редирект на /login.
const _protected = <String>{Routes.profile};

/// Провайдер роутера. Редирект завязан на [authControllerProvider]:
/// пока статус `unknown` — держим пользователя на splash; дальше пускаем по
/// правилам (гость не попадёт в защищённые разделы).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.profile, builder: (context, state) => const ProfileScreen()),
      GoRoute(path: Routes.servicesTrash, builder: (context, state) => const TrashScreen()),
      GoRoute(path: Routes.servicesCoffee, builder: (context, state) => const CoffeeScreen()),
      GoRoute(path: Routes.servicesBreakfast, builder: (context, state) => const BreakfastScreen()),
      GoRoute(
        path: '/services/breakfast/:slug',
        builder: (context, state) => BreakfastDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: Routes.servicesWater, builder: (context, state) => const WaterScreen()),
      GoRoute(path: Routes.servicesProducts, builder: (context, state) => const ProductsScreen()),
      GoRoute(path: '/services/products/search', builder: (context, state) => const ProductSearchScreen()),
      GoRoute(path: '/services/products/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(
        path: '/services/products/cat/:id',
        builder: (context, state) => ProductCategoryScreen(catId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/services/products/:id',
        builder: (context, state) => ProductDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.pvz, builder: (context, state) => const PvzScreen()),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
      GoRoute(path: '/coupons', builder: (context, state) => const CouponsScreen()),
      GoRoute(path: '/services/request', builder: (context, state) => const AssistantScreen()),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      // 1) Идёт стартовая проверка — всех держим на splash.
      if (auth.status == AuthStatus.unknown) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      // 2) Проверка закончилась, а мы ещё на splash — уводим на главную.
      if (loc == Routes.splash) return Routes.home;

      // 3) Гость лезет в защищённый раздел — на вход.
      final isGuest = auth.status == AuthStatus.guest;
      if (isGuest && _protected.contains(loc)) return Routes.login;

      // 4) Уже вошёл, но открыл /login — отправляем домой.
      if (auth.isAuthed && loc == Routes.login) return Routes.home;

      return null;
    },
  );
});

/// Мост Riverpod → Listenable для go_router: дёргает перерасчёт редиректа
/// при каждом изменении состояния авторизации.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}
