import '../../core/network/dio_client.dart';

/// Результат создания заказа (`/api/orders`, `/api/services/order`).
class OrderResult {
  const OrderResult({required this.id, required this.number, this.total});
  final String id;
  final String number;
  final int? total;

  factory OrderResult.fromJson(Map<String, dynamic> j) => OrderResult(
        id: j['id'] as String,
        number: (j['number'] ?? '') as String,
        total: (j['total'] as num?)?.toInt(),
      );
}

/// Краткая карточка заказа (список активных) — `/api/orders/active`.
class OrderSummary {
  const OrderSummary({required this.id, required this.number, required this.status, required this.total, this.etaMinutes, this.createdAt});
  final String id;
  final String number;
  final String status; // created/paid/picking/delivering/delivered/cancelled/completed
  final int total;
  final int? etaMinutes;
  final DateTime? createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        id: j['id'] as String,
        number: (j['number'] ?? '') as String,
        status: (j['status'] ?? 'created') as String,
        total: (j['total'] as num?)?.toInt() ?? 0,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt(),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      );
}

/// Результат запроса оплаты (`POST /api/orders/[id]/pay`).
/// kind: 'redirect' → открыть [confirmationUrl] (страница ЮKassa);
///       'paid'     → заказ уже оплачен (0₽ / кошелёк).
class PayResult {
  const PayResult({required this.kind, this.confirmationUrl, this.confirmationToken, this.orderId});
  final String kind; // embedded | redirect | paid
  final String? confirmationUrl; // для redirect
  final String? confirmationToken; // для embedded (виджет ЮKassa)
  final String? orderId;

  factory PayResult.fromJson(Map<String, dynamic> j) => PayResult(
        kind: (j['kind'] ?? '') as String,
        confirmationUrl: j['confirmationUrl'] as String?,
        confirmationToken: j['confirmationToken'] as String?,
        orderId: j['orderId'] as String?,
      );
}

/// Создание заказов. Требует авторизации (сессия-cookie через интерсептор).
class OrdersApi {
  OrdersApi(this._dio);
  final DioClient _dio;

  /// Запросить оплату заказа картой → confirmationUrl (страница ЮKassa).
  Future<PayResult> payOrder(String id, {String method = 'card'}) async {
    final res = await _dio.post('/orders/$id/pay', data: {'method': method});
    return PayResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Отменить заказ (используется для очистки тестовых заказов).
  Future<void> cancelOrder(String id) async {
    await _dio.post('/orders/$id/cancel');
  }

  /// Активные заказы пользователя (до 5, новые сверху).
  Future<List<OrderSummary>> activeOrders() async {
    final res = await _dio.get('/orders/active');
    final list = (res.data is Map ? res.data['orders'] : null) as List? ?? const [];
    return list.map((e) => OrderSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Товары магазина → POST /orders.
  Future<OrderResult> createProductOrder({
    required List<({String productId, int qty})> items,
    String? comment,
    Map<String, dynamic>? addressOverride,
  }) async {
    final res = await _dio.post('/orders', data: {
      'items': [for (final it in items) {'productId': it.productId, 'qty': it.qty}],
      if (comment != null) 'comment': comment,
      if (addressOverride != null) 'addressOverride': addressOverride,
    });
    return OrderResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Услуги (кофе/вода/мусор/завтрак) → POST /services/order.
  Future<OrderResult> createServiceOrder({
    required String kind,
    required String phone,
    required String address,
    required Map<String, dynamic> details,
    required int total,
    required int itemsTotal,
    int deliveryFee = 0,
    int deliveryEtaMin = 15,
  }) async {
    final res = await _dio.post('/services/order', data: {
      'kind': kind,
      'phone': phone,
      'address': address,
      'details': details,
      'total': total,
      'itemsTotal': itemsTotal,
      'deliveryFee': deliveryFee,
      'deliveryEtaMin': deliveryEtaMin,
    });
    return OrderResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
