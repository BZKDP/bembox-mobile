import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../error/failures.dart';
import '../storage/session_store.dart';
import 'auth_interceptor.dart';

/// Фабрика и обёртка над [Dio] — единая точка сетевого доступа.
///
/// Здесь настраиваются базовый URL, тайм-ауты, заголовки, логирование и
/// интерсептор авторизации. Все API-классы (`data/api/*`) используют этот Dio.
class DioClient {
  DioClient(this._session) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        // Бэкенд почти везде отвечает JSON'ом; принимаем любые статусы < 500,
        // чтобы 4xx (с полем `error`) обрабатывать самим, а не как исключение.
        validateStatus: (code) => code != null && code < 500,
        headers: {
          'User-Agent': AppConfig.userAgent,
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(AuthInterceptor(_session));

    if (AppConfig.networkLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          logPrint: (o) => _log(o.toString()),
        ),
      );
    }
  }

  final SessionStore _session;
  late final Dio _dio;

  Dio get raw => _dio;

  void _log(String s) {
    // ignore: avoid_print
    print('[net] $s');
  }

  /// GET с единым разбором ошибок.
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => _dio.get(path, queryParameters: query));

  /// POST с единым разбором ошибок.
  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _wrap(() => _dio.post(path, data: data));

  /// PATCH.
  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _wrap(() => _dio.patch(path, data: data));

  /// DELETE.
  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _wrap(() => _dio.delete(path, data: data));

  /// Выполняет запрос и превращает любые сбои в [AppFailure].
  /// Также трактует 4xx с телом `{error: "..."}` как [ApiFailure]/[UnauthorizedFailure].
  Future<Response<dynamic>> _wrap(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      if (code == 401) {
        throw const UnauthorizedFailure();
      }
      if (code >= 400) {
        throw ApiFailure(_extractError(res.data), statusCode: code);
      }
      return res;
    } on AppFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (_) {
      throw const UnknownFailure();
    }
  }

  AppFailure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return const UnauthorizedFailure();
        return ApiFailure(_extractError(e.response?.data), statusCode: code);
      default:
        return const UnknownFailure();
    }
  }

  /// Достаёт человекочитаемый текст ошибки из тела ответа бэкенда.
  /// Бэкенд возвращает `{ "error": "текст" }` (см. route.ts по всему API).
  String _extractError(dynamic data) {
    if (data is Map && data['error'] is String) return data['error'] as String;
    return 'Ошибка сервера';
  }
}
