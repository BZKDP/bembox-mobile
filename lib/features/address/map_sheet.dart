import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/api/geo_api.dart';

const _coral = Color(0xFFFF7547);
const _coralDeep = Color(0xFFE85522);
const _trekhgorka = LatLng(55.6745, 37.2585); // Новая Трёхгорка — безопасный дефолт

/// Открыть выбор адреса на карте (порт `MapSheet.tsx`). При подтверждении
/// сохраняет адрес в /api/me и обновляет authState → адрес меняется везде.
Future<void> showAddressMapSheet(BuildContext context, WidgetRef ref) async {
  final picked = await showModalBottomSheet<_Picked>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x73000000),
    builder: (_) => const _MapSheet(),
  );
  if (picked == null) return;
  // Сохраняем точку локально + адрес на сервере, обновляем профиль.
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setDouble('bem-geo-lat', picked.lat);
  await prefs.setDouble('bem-geo-lng', picked.lng);
  if (picked.address != null && picked.address!.isNotEmpty) {
    try {
      await ref.read(meApiProvider).setLastAddress(picked.address!);
      await ref.read(authControllerProvider.notifier).onLoggedIn(); // перечитать /me
    } catch (_) {/* офлайн — адрес хотя бы сохранён локально */}
  }
}

class _Picked {
  const _Picked(this.lat, this.lng, this.address);
  final double lat;
  final double lng;
  final String? address;
}

class _MapSheet extends ConsumerStatefulWidget {
  const _MapSheet();
  @override
  ConsumerState<_MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends ConsumerState<_MapSheet> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();

  LatLng _center = _trekhgorka;
  bool _moving = false;
  String? _address;
  bool _resolving = false;
  DeliveryZone? _zone;
  bool _inZone = false;

  Timer? _revDebounce;
  Timer? _moveStop;
  Timer? _searchDebounce;

  bool _searchOpen = false;
  bool _searching = false;
  List<AddrSuggestion> _suggestions = const [];

  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Стартовая точка: сохранённая → дефолт.
    final prefs = ref.read(sharedPreferencesProvider);
    final sLat = prefs.getDouble('bem-geo-lat');
    final sLng = prefs.getDouble('bem-geo-lng');
    if (sLat != null && sLng != null && sLat.abs() > 0.0001) {
      _center = LatLng(sLat, sLng);
    }
    _loadZone();
    _reverse(_center);
    // Авто-определение при открытии — как `MapSheet` на сайте (запрос
    // разрешения + центрирование на пользователе). Задержка — чтобы карта
    // успела инициализироваться для _map.move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _doLocate(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _revDebounce?.cancel();
    _moveStop?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _loadZone() async {
    final z = await ref.read(geoApiProvider).zone();
    if (!mounted || z == null) return;
    setState(() {
      _zone = z;
      _inZone = _pointInZone(_center);
    });
  }

  bool _pointInZone(LatLng p) {
    final poly = _zone?.polygon;
    if (poly == null || poly.length < 3) return false;
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final yi = poly[i][0], xi = poly[i][1];
      final yj = poly[j][0], xj = poly[j][1];
      final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  void _onMove(MapCamera cam, bool hasGesture) {
    _center = cam.center;
    if (!_moving) setState(() => _moving = true);
    _moveStop?.cancel();
    _moveStop = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _moving = false);
    });
    setState(() => _inZone = _pointInZone(_center));
    _revDebounce?.cancel();
    _revDebounce = Timer(const Duration(milliseconds: 500), () => _reverse(_center));
  }

  Future<void> _reverse(LatLng p) async {
    if (!mounted) return;
    setState(() => _resolving = true);
    final a = await ref.read(geoApiProvider).reverse(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      if (a != null && a.isNotEmpty) _address = a;
      _resolving = false;
    });
  }

  /// Тап по кнопке «моё местоположение».
  Future<void> _locateMe() => _doLocate(silent: false);

  /// Определить геопозицию: запросить разрешение → центрировать карту.
  /// silent=true (авто при открытии) — без снекбаров при отказе/ошибке.
  Future<void> _doLocate({required bool silent}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет доступа к геолокации — введите адрес вручную')));
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Включите геолокацию в телефоне')));
        return;
      }
      // Сначала быстрый кэш (мгновенно центрируем), затем точный фикс.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) _applyLocation(last.latitude, last.longitude);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      if (mounted) _applyLocation(pos.latitude, pos.longitude);
    } catch (_) {
      if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось определить местоположение')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _applyLocation(double lat, double lng) {
    final ll = LatLng(lat, lng);
    _map.move(ll, 16);
    _center = ll;
    setState(() => _inZone = _pointInZone(ll));
    _reverse(ll);
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final items = await ref.read(geoApiProvider).search(q.trim());
      if (!mounted) return;
      setState(() { _suggestions = items; _searching = false; });
    });
  }

  void _pick(AddrSuggestion s) {
    final ll = LatLng(s.lat, s.lng);
    _map.move(ll, 17);
    _center = ll;
    setState(() {
      _address = s.title;
      _inZone = _pointInZone(ll);
      _searchOpen = false;
      _suggestions = const [];
    });
    _searchCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      constraints: BoxConstraints(maxHeight: h * 0.92),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0x1A000000), borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Куда привезти', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink))),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 20, color: BemColors.mute)),
          ),
        ]),
        const SizedBox(height: 12),
        // ── Карта ──
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 340,
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
                  onPositionChanged: _onMove,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://bembox.ru/api/map/tile/{z}/{x}/{y}',
                    maxNativeZoom: 19,
                    userAgentPackageName: 'ru.bembox.app',
                  ),
                  if (_zone != null && _zone!.polygon.length >= 3)
                    PolygonLayer(polygons: [
                      Polygon(
                        points: [for (final p in _zone!.polygon) LatLng(p[0], p[1])],
                        color: _coral.withValues(alpha: 0.16),
                        borderColor: _coral,
                        borderStrokeWidth: 2,
                      ),
                    ]),
                ],
              ),
              // Центральный пин (поднимается при движении).
              IgnorePointer(
                child: Center(
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 150),
                    offset: Offset(0, _moving ? -0.10 : 0),
                    // Сдвигаем вверх на половину высоты, чтобы остриё было в центре.
                    child: Transform.translate(
                      offset: const Offset(0, -23),
                      child: const Icon(Icons.location_on, size: 46, color: _coral, shadows: [Shadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 4))]),
                    ),
                  ),
                ),
              ),
              // Статус-пилюля.
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, spreadRadius: -2)]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_inZone ? Icons.check : Icons.close, size: 13, color: _inZone ? _coralDeep : BemColors.mute),
                    const SizedBox(width: 5),
                    Text(_inZone ? 'Соседская доставка' : 'Вне зон', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _inZone ? _coralDeep : BemColors.mute)),
                  ]),
                ),
              ),
              // Кнопка «моё местоположение».
              Positioned(
                bottom: 12, right: 12,
                child: GestureDetector(
                  onTap: _locateMe,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, spreadRadius: -2)]),
                    child: _locating
                        ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.4, color: _coral))
                        : const Icon(Icons.near_me, size: 19, color: _coral),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // ── Адрес + «ввести» ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0x0A000000), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _inZone ? _coral : BemColors.mute, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.home_outlined, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(_resolving ? 'Определяю адрес…' : (_address ?? 'Адрес определяется…'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BemColors.ink)),
              const SizedBox(height: 2),
              Text(_inZone ? 'Соседская доставка · кофе/мусор/вода' : 'Вне зон · можно оставить заявку', style: const TextStyle(fontSize: 11, color: BemColors.mute)),
            ])),
            GestureDetector(
              onTap: () => setState(() => _searchOpen = !_searchOpen),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: _coral.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 13, color: _coral), SizedBox(width: 4), Text('ввести', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _coral))]),
              ),
            ),
          ]),
        ),
        // ── Поиск адреса ──
        if (_searchOpen) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0x0A000000), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.search, size: 18, color: BemColors.mute),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14, color: BemColors.ink),
                decoration: const InputDecoration(isCollapsed: true, contentPadding: EdgeInsets.symmetric(vertical: 12), border: InputBorder.none, hintText: 'Улица, дом — напр. Кутузовская 5', hintStyle: TextStyle(fontSize: 14, color: BemColors.mute)),
              )),
            ]),
          ),
          if (_searchCtrl.text.trim().length >= 2)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(top: 6), children: [
                if (_searching && _suggestions.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text('Ищу адреса…', style: TextStyle(fontSize: 12, color: BemColors.mute))),
                if (!_searching && _suggestions.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text('Ничего не нашлось.', style: TextStyle(fontSize: 12, color: BemColors.mute))),
                for (final s in _suggestions)
                  GestureDetector(
                    onTap: () => _pick(s),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BemColors.ink)),
                        if (s.subtitle.isNotEmpty) Text(s.subtitle, style: const TextStyle(fontSize: 11, color: BemColors.mute)),
                      ]),
                    ),
                  ),
              ]),
            ),
        ],
        const SizedBox(height: 12),
        // ── Подтвердить ──
        GestureDetector(
          onTap: () => Navigator.of(context).pop(_Picked(_center.latitude, _center.longitude, _address)),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _inZone ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_coral, _coralDeep]) : null,
              color: _inZone ? null : const Color(0xFF5C5048),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _inZone ? const [BoxShadow(color: Color(0x80E8551F), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 10))] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_inZone ? 'Это мой дом' : 'Поставить точку (вне зон)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              if (_inZone) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}
