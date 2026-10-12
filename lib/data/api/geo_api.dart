import '../../core/network/dio_client.dart';

/// Подсказка адреса из поиска (`/api/geocode/search`).
class AddrSuggestion {
  const AddrSuggestion({required this.title, required this.subtitle, required this.lat, required this.lng});
  final String title;
  final String subtitle;
  final double lat;
  final double lng;
}

/// Зона доставки (`/api/zone`): полигон [[lat,lng], ...] + центр.
class DeliveryZone {
  const DeliveryZone({required this.polygon, this.centerLat, this.centerLng});
  final List<List<double>> polygon; // [[lat,lng], ...]
  final double? centerLat;
  final double? centerLng;
}

/// Геокодинг и зона — порт серверных ручек `/api/geocode/*`, `/api/zone`.
class GeoApi {
  GeoApi(this._dio);
  final DioClient _dio;

  /// Точка → адрес. GET /geocode/reverse?lat=&lng= → {address}.
  Future<String?> reverse(double lat, double lng) async {
    try {
      final res = await _dio.get('/geocode/reverse', query: {'lat': lat, 'lng': lng});
      final d = res.data;
      return (d is Map ? d['address'] as String? : null);
    } catch (_) {
      return null;
    }
  }

  /// Поиск адреса. GET /geocode/search?q= → {items:[{title,subtitle,lat,lng}]}.
  Future<List<AddrSuggestion>> search(String q) async {
    try {
      final res = await _dio.get('/geocode/search', query: {'q': q});
      final items = (res.data is Map ? res.data['items'] : null) as List? ?? const [];
      return [
        for (final e in items)
          if (e is Map)
            AddrSuggestion(
              title: (e['title'] ?? '').toString(),
              subtitle: (e['subtitle'] ?? '').toString(),
              lat: (e['lat'] as num?)?.toDouble() ?? 0,
              lng: (e['lng'] as num?)?.toDouble() ?? 0,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Зона доставки. GET /zone → {polygon, centerLat, centerLng}.
  Future<DeliveryZone?> zone() async {
    try {
      final res = await _dio.get('/zone');
      final d = res.data;
      if (d is! Map) return null;
      final poly = (d['polygon'] as List?) ?? const [];
      final parsed = <List<double>>[];
      for (final p in poly) {
        if (p is List && p.length >= 2) {
          parsed.add([(p[0] as num).toDouble(), (p[1] as num).toDouble()]);
        }
      }
      return DeliveryZone(
        polygon: parsed,
        centerLat: (d['centerLat'] as num?)?.toDouble(),
        centerLng: (d['centerLng'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
