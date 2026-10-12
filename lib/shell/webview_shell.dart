import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/crash_reporter.dart';
import '../push/fcm_service.dart';
import '../push/push_service.dart';

/// Бренд bembox.
const _coral = Color(0xFFFF7547);
const _coralDeep = Color(0xFFE8551F);
const _beige = Color(0xFFFFFCF6);

/// Базовый URL живого сайта, который оборачиваем.
const _siteUrl = 'https://bembox.ru';

/// Версия для сброса кэша WebView. WebView настроен cacheEnabled:true и держит
/// закэшированную страницу между запусками (так логин/состояние не слетают). Но
/// из-за этого у пользователей «залипала» старая версия главной (битый символ «?»
/// в подзаголовке из промежуточного билда сайта). Грузим стартовый URL с этим
/// параметром: при его смене WebView видит НОВЫЙ URL и тянет свежую страницу в
/// обход старого кэша `/`. Бампать при подобных «залипаниях». (Тимофей 2026-06-22)
const _siteRev = '20260622';

/// Стартовый URL с cache-buster (см. _siteRev). Сайт лишние query-параметры игнорит.
const _entryUrl = '$_siteUrl/?cb=$_siteRev';

/// iOS: WebView идёт edge-to-edge (под статус-бар), поэтому добавляем сайту
/// отступ сверху на высоту safe-area через env(safe-area-inset-top) — чтобы
/// верхний контент (шапка с адресом) не налезал на часы/батарею. Низ не трогаем
/// (там и так ок). На Android WebView не edge-to-edge → env=0 → это no-op.
const _safeAreaJs = r'''
(function(){
  try {
    var vp = document.querySelector('meta[name=viewport]');
    if (vp) {
      var c = vp.getAttribute('content') || '';
      if (c.indexOf('viewport-fit') < 0) vp.setAttribute('content', (c ? c + ', ' : '') + 'viewport-fit=cover');
    }
    var id = 'bem-safearea-style';
    if (!document.getElementById(id)) {
      var s = document.createElement('style');
      s.id = id;
      s.textContent = 'html{padding-top:env(safe-area-inset-top,0px) !important;}';
      (document.head || document.documentElement).appendChild(s);
    }
  } catch(e){}
})();
''';

/// Скрипт, который убирает баннер «Сайт использует cookies» в приложении
/// (требование модерации стора: не показывать упоминание о cookies).
/// Работает механизмом самого сайта: компонент CookieConsent не отрисовывается,
/// если в localStorage уже есть выбор `bem-cookie-consent`. Выставляем
/// 'essential' ДО загрузки страницы (без побочного запроса гео, который даёт
/// только вариант 'all'). Плюс defensive-удаление, если баннер всё же успел
/// отрисоваться (SPA-перерисовки ловит MutationObserver).
const _cookieKillJs = r'''
(function(){
  try { localStorage.setItem('bem-cookie-consent','essential'); } catch(e){}
  function kill(){
    try{
      var bs = document.getElementsByTagName('b');
      for (var i=0;i<bs.length;i++){
        var t = bs[i].textContent || '';
        if (t.indexOf('cookies') > -1 && t.indexOf('использует') > -1){
          var p = bs[i];
          while (p && p !== document.body){
            var cs = window.getComputedStyle(p);
            if (cs && cs.position === 'fixed'){ p.remove(); return; }
            p = p.parentElement;
          }
          return;
        }
      }
    } catch(e){}
  }
  if (document.readyState !== 'loading') kill();
  document.addEventListener('DOMContentLoaded', kill);
  try { new MutationObserver(kill).observe(document.documentElement, {childList:true, subtree:true}); } catch(e){}
  setTimeout(kill, 400); setTimeout(kill, 1200);
})();
''';

/// Хосты, которые остаются ВНУТРИ WebView (сам сайт + платёжный виджет ЮKassa +
/// карты-тайлы и т.п.). Всё остальное (чужие домены) уходит в системный браузер.
const _internalHosts = <String>{
  'bembox.ru',
  'www.bembox.ru',
  'yoomoney.ru',
  'static.yoomoney.ru',
  'yookassa.ru',
  'api.yookassa.ru',
  'sberbank.ru',
  '3dsec.sberbank.ru',
  'securepayments.sberbank.ru',
};

/// Схемы, которые НЕ являются http(s): звонилка, почта, deep-link платёжных
/// приложений (SberPay/T-Pay/Mir Pay) — отдаём системе.
bool _isExternalScheme(String scheme) {
  return scheme != 'http' && scheme != 'https' && scheme != 'about';
}

/// Тонкая нативная оболочка: один full-screen WebView поверх bembox.ru.
class WebViewShell extends StatefulWidget {
  const WebViewShell({super.key});

  @override
  State<WebViewShell> createState() => _WebViewShellState();
}

class _WebViewShellState extends State<WebViewShell>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefresh;
  // Меняем ключ → InAppWebView пересоздаётся (после смерти render-процесса).
  Key _webViewKey = UniqueKey();

  bool _firstLoadDone = false; // погас ли сплеш
  bool _offline = false; // показывать экран «нет интернета»
  bool _pageLooksDead = false; // страница загрузилась, но тело пустое (React не ожил)
  bool _healthChecked = false; // проверку «живости» уже делали (один раз за старт)
  bool _recovering = false; // идёт очистка+перезагрузка (блокируем повторные тапы)
  double _progress = 0;
  DateTime? _lastBackPress; // для «нажмите назад ещё раз для выхода»

  // Пуши RuStore.
  final BemboxPush _push = BemboxPush();
  // Пуши FCM (Firebase) — iOS + Android с Google Play Services.
  final BemboxFcm _fcm = BemboxFcm();
  String? _pendingPushUrl; // тап по пушу до готовности WebView

  // Нативный мост (производитель устройства + экран автозапуска OEM).
  static const MethodChannel _sys = MethodChannel('bembox/system');
  bool _notifAsked = false; // разрешение на уведомления спросили (один раз)
  bool _oemHintChecked = false; // подсказку про автозапуск уже проверяли

  late final StreamSubscription<List<ConnectivityResult>> _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Нативный pull-to-refresh ОТКЛЮЧЁН намеренно: на нативном уровне он
    // перехватывал жест «потянуть вниз» ДО веб-страницы, из-за чего ломались
    // свайп-вниз жесты внутри сайта (закрытие шторок: карта адреса, листы
    // товаров и т.п. — на сайте в браузере работают, в приложении нет).
    // Перезагрузка доступна по навигации и кнопкой «повторить» на офлайн-экране.

    // Разрешения (гео/камера) НЕ спрашиваем на старте — это раздражает двумя
    // диалогами сразу. Запрашиваем лениво в момент, когда сайт реально просит
    // функцию (onPermissionRequest / onGeolocationPermissionsShowPrompt).

    // Слушаем сеть: если интернет вернулся на офлайн-экране — авто-перезагрузка.
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet && _offline) {
        _reloadFromOffline();
      }
    });

    // Разрешение на уведомления НЕ просим на холодном старте (раздражает и
    // налезает на сплеш). Просим лениво — один раз после первой загрузки
    // (_scheduleNotifAsk), а для прошедших онбординг диалог уже показан там.

    // Пуши RuStore: тап по пушу открывает экран в WebView; новый токен —
    // регистрируем на бэкенде силами самой страницы (с cookie-сессией).
    _push.onOpenUrl = _openPushUrl;
    _push.onToken = (token) async {
      await _tryRegisterPushToken();
    };
    _push.init();

    // FCM: тап по пушу открывает экран; токен регистрируем силами страницы.
    _fcm.onOpenUrl = _openPushUrl;
    _fcm.onToken = (token) async {
      await _tryRegisterFcmToken();
    };
    _fcm.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Возврат из фона: перепривязываем токен (вдруг пользователь вошёл по SMS
    // без полной перезагрузки страницы).
    if (state == AppLifecycleState.resumed) {
      _tryRegisterPushToken();
      _tryRegisterFcmToken();
      _tryRegisterApnsToken();
      _consumePushRoute();
    }
  }

  /// Открыть путь из пуша внутри WebView. Если WebView ещё не готов — запомним
  /// и откроем после первой загрузки.
  void _openPushUrl(String url) {
    final full = url.startsWith('http') ? url : '$_siteUrl$url';
    final c = _controller;
    if (c != null && _firstLoadDone) {
      c.loadUrl(urlRequest: URLRequest(url: WebUri(full)));
    } else {
      _pendingPushUrl = full;
    }
  }

  /// Зарегистрировать пуш-токен на бэкенде через fetch внутри страницы (cookie
  /// bemboks_sid подставится автоматически). Вызываем на КАЖДОЙ загрузке страницы
  /// и при возврате приложения из фона — так токен привязывается к пользователю
  /// сразу после входа по SMS (а не остаётся с user_id=NULL до перезапуска).
  /// Бэкенд делает upsert по token, поэтому повторные вызовы безопасны.
  Future<void> _tryRegisterPushToken() async {
    final c = _controller;
    final token = _push.token;
    if (c == null || token == null || !_firstLoadDone) return;
    try {
      await c.evaluateJavascript(source: BemboxPush.buildRegisterJs(token));
    } catch (_) {}
  }

  /// Зарегистрировать FCM-токен (Firebase) на бэкенде силами страницы. Вызываем
  /// на каждой загрузке и при возврате из фона — токен привязывается к юзеру
  /// сразу после входа по SMS. Бэкенд делает upsert по token (idempotent).
  Future<void> _tryRegisterFcmToken() async {
    final c = _controller;
    final token = _fcm.token;
    if (c == null || token == null || !_firstLoadDone) return;
    try {
      await c.evaluateJavascript(
        source: BemboxPush.buildRegisterJsFcm(token, ios: Platform.isIOS),
      );
    } catch (_) {}
  }

  /// Зарегистрировать iOS APNs-токен. Нативный код (AppDelegate) кладёт его в
  /// UserDefaults (ключ flutter.bem_apns_token) — читаем через shared_preferences
  /// и регистрируем на бэке силами страницы (cookie-сессия подставится сама).
  Future<void> _tryRegisterApnsToken() async {
    if (!Platform.isIOS) return;
    final c = _controller;
    if (c == null || !_firstLoadDone) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // reload() обязателен: токен пишет нативный код (AppDelegate) в UserDefaults
      // уже после старта, а getInstance() отдаёт кэш — без reload Dart его не увидит.
      await prefs.reload();
      final token = prefs.getString('bem_apns_token');
      if (token == null || token.isEmpty) return;
      await c.evaluateJavascript(source: BemboxPush.buildRegisterJsIos(token));
    } catch (_) {}
  }

  /// Открыть экран из тапнутого пуша (iOS). Нативный делегат (AppDelegate) кладёт
  /// route в UserDefaults (flutter.bem_push_route) — читаем, грузим в WebView, чистим.
  Future<void> _consumePushRoute() async {
    final c = _controller;
    if (c == null || !_firstLoadDone) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final route = prefs.getString('bem_push_route');
      if (route == null || route.isEmpty) return;
      await prefs.remove('bem_push_route');
      final full = route.startsWith('http') ? route : '$_siteUrl$route';
      await c.loadUrl(urlRequest: URLRequest(url: WebUri(full)));
    } catch (_) {}
  }

  /// Лениво (один раз, через короткую задержку после первого кадра) просим
  /// разрешение на уведомления. Не на старте — чтобы диалог не налезал на сплеш.
  /// Для прошедших онбординг ОС уже знает ответ → второго диалога не будет.
  void _scheduleNotifAsk() {
    if (_notifAsked) return;
    _notifAsked = true;
    Future.delayed(const Duration(milliseconds: 1500), () async {
      try {
        await Permission.notification.request();
      } catch (_) {}
    });
  }

  /// На «агрессивных» прошивках (MIUI/EMUI/ColorOS/FuntouchOS…) система может
  /// усыплять приложение и убивать foreground-service статуса заказа. Один раз
  /// мягко подсказываем включить автозапуск/снять экономию батареи.
  Future<void> _maybeShowOemHint() async {
    if (_oemHintChecked || !Platform.isAndroid) return;
    _oemHintChecked = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('bem-oem-hint-shown') ?? false) return;
      final mf =
          (await _sys.invokeMethod<String>('manufacturer'))?.toLowerCase() ??
              '';
      const aggressive = [
        'xiaomi', 'redmi', 'poco', 'huawei', 'honor', 'oppo',
        'realme', 'vivo', 'iqoo', 'meizu', 'letv', 'oneplus',
      ];
      if (!aggressive.any(mf.contains)) return;
      await prefs.setBool('bem-oem-hint-shown', true);
      if (!mounted) return;
      _showOemHintDialog();
    } catch (_) {}
  }

  void _showOemHintDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Чтобы статус заказа не пропадал',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _coralDeep,
          ),
        ),
        content: const Text(
          'На вашем телефоне система может «усыплять» приложения. Разрешите '
          'bembox автозапуск и отключите экономию батареи — тогда уведомление '
          'о курьере будет обновляться надёжно.',
          style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Позже',
              style: TextStyle(
                color: Color(0xFF8A8178),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _sys.invokeMethod('openOemSettings');
              } catch (_) {}
            },
            child: const Text(
              'Открыть настройки',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub.cancel();
    super.dispose();
  }

  /// Системная «назад». Сайт — Next.js SPA со смешанной навигацией: часть
  /// переходов — настоящие роуты (pushState, URL меняется и видна нативному
  /// canGoBack()), часть — оверлеи/шиты без смены URL. Чтобы НИКОГДА случайно
  /// не закрыть приложение одним нажатием, действуем так:
  /// 1) есть нативная история → goBack();
  /// 2) иначе пробуем JS-историю сайта и смотрим, сменился ли URL — если да,
  ///    сайт сам что-то закрыл/перешёл, остаёмся в приложении;
  /// 3) если идти реально некуда — выходим только по ДВОЙНОМУ «назад» за 2 сек,
  ///    показав подсказку (стандартный безопасный паттерн Android).
  Future<void> _handleBack() async {
    final c = _controller;
    if (c == null) {
      await SystemNavigator.pop();
      return;
    }
    if (await c.canGoBack()) {
      await c.goBack();
      _lastBackPress = null;
      return;
    }
    // Нет нативной истории — пробуем SPA-историю/закрытие оверлея силами сайта.
    final before = (await c.getUrl())?.toString();
    await c.evaluateJavascript(source: 'window.history.back();');
    await Future.delayed(const Duration(milliseconds: 350));
    final after = (await c.getUrl())?.toString();
    if (before != after) {
      _lastBackPress = null;
      return; // сайт перешёл/закрыл оверлей — остаёмся.
    }
    // Идти некуда → выход по двойному «назад».
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('нажмите «назад» ещё раз, чтобы выйти'),
          duration: Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _reloadFromOffline() async {
    setState(() => _offline = false);
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_entryUrl)),
    );
  }

  /// Один раз за холодный старт, через короткую паузу после загрузки, проверяем
  /// что страница реально отрисовала контент. Симптом проблемы у пользователя:
  /// сайт «загрузился» (200 OK), но JS не ожил (старый WebView / протухшее
  /// состояние) → тело пустое, кнопки мёртвые. В этом случае показываем оверлей
  /// с кнопкой восстановления — чтобы человек не остался один на один с белым
  /// экраном без выхода.
  void _scheduleHealthCheck() {
    if (_healthChecked) return;
    _healthChecked = true;
    Future.delayed(const Duration(milliseconds: 3000), _probePageHealth);
  }

  Future<void> _probePageHealth() async {
    final c = _controller;
    if (c == null || !mounted || _offline) return;
    try {
      // Длина «полезного» текста на странице без пробелов. У живой главной
      // bembox.ru это сотни символов; у мёртвого/непровалившегося React-маунта —
      // почти ноль. Порог 24 — заведомо ниже любой реальной страницы сайта.
      final res = await c.evaluateJavascript(source: '''
        (function(){
          try {
            var b = document.body;
            if (!b) return 0;
            return (b.innerText || '').replace(/\\s/g,'').length;
          } catch(e){ return -1; }
        })()
      ''');
      // res == null → JS вообще не выполнился: НЕ считаем мёртвым (избегаем ложных
      // срабатываний на гонке), просто молча выходим. Реальную причину поймает
      // onConsoleMessage. Только явный маленький размер тела → страница мертва.
      final len = (res is num) ? res.toInt() : null;
      if (len != null && len >= 0 && len < 24) {
        CrashReporter.record(
          'dead page detected (bodyTextLen=$len)',
          null,
          source: 'webview',
        );
        if (mounted) setState(() => _pageLooksDead = true);
      }
    } catch (_) {
      // Не удалось проверить — не трогаем UI (без ложных тревог).
    }
  }

  /// Аварийное восстановление: чистим HTTP-кэш WebView и web-storage
  /// (localStorage/IndexedDB), затем грузим главную с cache-buster заново.
  /// Куки-сессию не трогаем (на Android) → логин сохраняется. Тот же путь, что
  /// и авто-лечение при обновлении приложения, но запускается вручную, когда
  /// страница «залипла» прямо сейчас.
  Future<void> _clearAndReload() async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      await InAppWebViewController.clearAllCache();
      if (Platform.isAndroid) {
        await WebStorageManager.instance().deleteAllData();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _pageLooksDead = false;
      _offline = false;
      _firstLoadDone = false;
      _healthChecked = false;
      _recovering = false;
      // Полностью пересоздаём WebView с чистого листа.
      _controller = null;
      _webViewKey = UniqueKey();
    });
  }

  /// Открыть URL во внешнем приложении (браузер/звонилка/платёжное приложение).
  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // молча: например, нет приложения для tel: на планшете
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).padding;
    return PopScope(
      // Сами решаем, что делать с системной «назад»: листать историю WebView,
      // а из корня — выходить из приложения.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: _beige,
        // Отступы под системные панели задаём вручную (не SafeArea), чтобы
        // управлять величиной. ВЕРХ: на Android берём ПОЛОВИНУ статус-бара —
        // полный safe-area визуально «опускал» страницу слишком низко (у сайта
        // есть свой внутренний отступ сверху); на iOS держим полный (иначе шапка
        // налезает на чёлку/часы). НИЗ: на iOS 0 (edge-to-edge, home-indicator
        // поверх — чисто), на Android держим (там кнопки назад/домой).
        body: Padding(
          padding: EdgeInsets.only(
            top: Platform.isIOS ? insets.top : insets.top / 2,
            bottom: Platform.isIOS ? 0 : insets.bottom,
          ),
          child: Stack(
            children: [
              if (!_offline)
                InAppWebView(
                  key: _webViewKey,
                  initialUrlRequest: URLRequest(url: WebUri(_entryUrl)),
                  initialSettings: _webViewSettings(),
                  // Убираем cookie-баннер сайта ещё до его отрисовки.
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _cookieKillJs,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                    UserScript(
                      source: _safeAreaJs,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                    ),
                  ]),
                  onWebViewCreated: (c) => _controller = c,
                  onProgressChanged: (c, p) {
                    setState(() => _progress = p / 100);
                    if (p >= 100) _pullToRefresh?.endRefreshing();
                  },
                  onLoadStop: (c, url) async {
                    _pullToRefresh?.endRefreshing();
                    // Подстраховка: убрать cookie-баннер + safe-area отступ сверху.
                    await c.evaluateJavascript(source: _cookieKillJs);
                    await c.evaluateJavascript(source: _safeAreaJs);
                    if (!_firstLoadDone && mounted) {
                      setState(() => _firstLoadDone = true);
                      // После того как контент виден: лениво просим уведомления
                      // и (на «агрессивных» прошивках) подсказываем про автозапуск.
                      _scheduleNotifAsk();
                      _maybeShowOemHint();
                    }
                    // Открыть экран из пуша, если ждал готовности WebView.
                    final pending = _pendingPushUrl;
                    if (pending != null) {
                      _pendingPushUrl = null;
                      await c.loadUrl(
                        urlRequest: URLRequest(url: WebUri(pending)),
                      );
                      return;
                    }
                    // Зарегистрировать пуш-токен (страница загружена → cookie
                    // доступна для fetch с credentials).
                    await _tryRegisterPushToken();
                    await _tryRegisterFcmToken();
                    await _tryRegisterApnsToken();
                    await _consumePushRoute();
                    // Один раз за запуск проверить, что страница реально «ожила»
                    // (а не белый экран с мёртвыми кнопками).
                    _scheduleHealthCheck();
                  },
                  onConsoleMessage: (c, msg) {
                    // Логируем ТОЛЬКО ошибки/предупреждения консоли сайта — это
                    // диагностика «мёртвой» страницы у конкретного пользователя
                    // (хранится в кольцевом буфере CrashReporter.recent).
                    final lvl = msg.messageLevel;
                    if (lvl == ConsoleMessageLevel.ERROR ||
                        lvl == ConsoleMessageLevel.WARNING) {
                      CrashReporter.record(
                        'console[$lvl] ${msg.message}',
                        null,
                        source: 'webview-console',
                      );
                    }
                  },
                  onReceivedError: (c, request, error) {
                    // Ошибка ВЕРХНЕУРОВНЕВОГО документа (не подзапроса картинки)
                    // при отсутствии сети → офлайн-экран.
                    if (request.isForMainFrame ?? false) {
                      _handleMainFrameFailure();
                    }
                  },
                  onReceivedHttpError: (c, request, response) {
                    // 5xx на главном документе тоже показываем как сбой.
                    final isMain = request.isForMainFrame ?? false;
                    final code = response.statusCode ?? 0;
                    if (isMain && code >= 500) _handleMainFrameFailure();
                  },
                  onRenderProcessGone: (c, detail) async {
                    // Android: Chromium render-процесс умер (обычно нехватка
                    // памяти). Сам WebView после этого мёртв безвозвратно →
                    // пересоздаём виджет (новый ключ) и грузим заново: вместо
                    // белого/чёрного экрана пользователь видит сплеш и страницу.
                    CrashReporter.record(
                      'webview render gone (didCrash=${detail.didCrash})',
                      null,
                      source: 'webview',
                    );
                    _recoverWebView();
                  },
                  onWebContentProcessDidTerminate: (c) async {
                    // iOS-аналог: WKWebView убил content-процесс (память/сбой) —
                    // экран становится пустым. Пересоздаём и грузим заново.
                    CrashReporter.record(
                      'webview content process terminated',
                      null,
                      source: 'webview',
                    );
                    _recoverWebView();
                  },
                  shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
                  onPermissionRequest: (c, request) async {
                    // Камера (фото QR на ПВЗ) и микрофон (голосовой ввод в
                    // консьерже/ассистенте) — сначала берём ОС-разрешение,
                    // потом выдаём web-origin доступ. Без ОС-разрешения на
                    // микрофон getUserMedia в WebView падает, и сайт думает, что
                    // это встроенный браузер без микрофона («Откройте в Chrome»).
                    final res = request.resources;
                    if (res.contains(PermissionResourceType.CAMERA)) {
                      await Permission.camera.request();
                    }
                    if (res.contains(PermissionResourceType.MICROPHONE)) {
                      await Permission.microphone.request();
                    }
                    return PermissionResponse(
                      resources: res,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onGeolocationPermissionsShowPrompt: (c, origin) async {
                    // Карта адреса просит гео — берём ОС-разрешение в момент
                    // запроса (а не на старте), затем разрешаем origin.
                    final status =
                        await Permission.locationWhenInUse.request();
                    return GeolocationPermissionShowPromptResponse(
                      origin: origin,
                      allow: status.isGranted,
                      retain: true,
                    );
                  },
                  onDownloadStartRequest: (c, req) async {
                    await _openExternally(req.url);
                  },
                  onCreateWindow: (c, createReq) async {
                    // target=_blank / window.open → грузим в том же WebView,
                    // либо отправляем наружу, если это чужой домен.
                    final reqUrl = createReq.request.url;
                    if (reqUrl != null) {
                      final host = reqUrl.host;
                      if (_internalHosts.contains(host)) {
                        await c.loadUrl(urlRequest: createReq.request);
                      } else if (reqUrl.scheme == 'http' ||
                          reqUrl.scheme == 'https') {
                        await _openExternally(reqUrl);
                      } else {
                        await _openExternally(reqUrl);
                      }
                    }
                    return false;
                  },
                ),

              // Тонкая полоска прогресса под статус-баром при загрузке.
              if (!_offline && _firstLoadDone && _progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: _coral,
                  ),
                ),

              // Сплеш поверх WebView, пока не отрисовался первый кадр сайта.
              if (!_firstLoadDone && !_offline) const _BrandSplash(),

              // Экран «нет интернета».
              if (_offline)
                _OfflineScreen(
                  onRetry: _reloadFromOffline,
                  onClear: _clearAndReload,
                ),

              // Страница загрузилась, но «мертва» (пустое тело) → даём выход:
              // очистить кэш и перезагрузить, не уходя в настройки Android.
              if (_pageLooksDead && !_offline)
                _DeadPageScreen(
                  busy: _recovering,
                  onClear: _clearAndReload,
                  onIgnore: () => setState(() => _pageLooksDead = false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMainFrameFailure() {
    if (!mounted) return;
    _pullToRefresh?.endRefreshing();
    setState(() {
      _offline = true;
      _firstLoadDone = true;
    });
  }

  /// Пересоздать WebView после смерти его процесса (Android render / iOS content)
  /// и показать сплеш, пока грузится заново. Новый ключ заставляет Flutter
  /// выкинуть мёртвый виджет и поднять свежий с initialUrlRequest.
  void _recoverWebView() {
    if (!mounted) return;
    setState(() {
      _controller = null;
      _firstLoadDone = false;
      _webViewKey = UniqueKey();
    });
  }

  InAppWebViewSettings _webViewSettings() {
    return InAppWebViewSettings(
      // Метка приложения в User-Agent (ДОПИСЫВАЕТСЯ к дефолтному UA, не заменяет
      // его → мобильная вёрстка 390px по-прежнему детектится). По ней сайт
      // отличает НАШЕ приложение от встроенных браузеров (Telegram/VK) и не
      // показывает баннер «откройте в Chrome» (микрофон мы выдаём нативно).
      applicationNameForUserAgent: 'bemboxapp',
      // Базовое
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      supportMultipleWindows: true,
      transparentBackground: true,
      // Внешние ссылки/схемы перехватываем сами.
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      // Медиа/камера для виджетов и фото QR.
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: 'camera; microphone; geolocation; payment',
      iframeAllowFullscreen: true,
      // Гео внутри WebView (Android).
      geolocationEnabled: true,
      // Не даём зумить пальцами — это «приложение», а не браузер.
      supportZoom: false,
      // Куки/состояние сохраняются между запусками (логин не слетает).
      cacheEnabled: true,
      clearCache: false,
      // Загрузка фото/файлов из <input type=file> (фото QR/штрих-кода на ПВЗ):
      // открывает системный пикер камеры/галереи. Без доступа к файлам пикер
      // не сможет вернуть выбранное изображение странице.
      allowFileAccess: true,
      allowContentAccess: true,
      // ВАЖНО: User-Agent НЕ переопределяем — сайт детектит мобилку по нему и
      // отдаёт вёрстку 390px. Полная подмена UA сломала бы layout.
      // iOS UX
      disableLongPressContextMenuOnLinks: false,
      allowsBackForwardNavigationGestures: true,
      // Не подсвечивать tap синим (как в нативе).
      disableInputAccessoryView: false,
    );
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    final scheme = uri.scheme.toLowerCase();

    // tel:, mailto:, sms:, intent:, sberpay:, market:, deep-links платёжек.
    if (_isExternalScheme(scheme)) {
      await _openExternally(uri);
      return NavigationActionPolicy.CANCEL;
    }

    // http(s): свои домены — внутри, чужие — наружу.
    final host = uri.host.toLowerCase();
    if (_internalHosts.contains(host)) {
      return NavigationActionPolicy.ALLOW;
    }

    // Чужой http(s)-домен открываем в системном браузере (только для переходов
    // верхнего уровня по клику пользователя, чтобы не ломать редиректы оплаты).
    final isMainFrame = action.isForMainFrame;
    if (isMainFrame) {
      await _openExternally(uri);
      return NavigationActionPolicy.CANCEL;
    }

    // Подзапросы (скрипты/iframe ЮKassa с других доменов) — пропускаем.
    return NavigationActionPolicy.ALLOW;
  }
}

/// Брендовый сплеш bembox (строчными, без эмодзи, коралловый акцент).
class _BrandSplash extends StatelessWidget {
  const _BrandSplash();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _beige,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'bembox',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: _coralDeep,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: _coral),
            ),
          ],
        ),
      ),
    );
  }
}

/// Экран «нет интернета» с кнопкой «повторить» и вторичной «очистить кэш».
class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen({required this.onRetry, required this.onClear});

  final Future<void> Function() onRetry;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _beige,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: _coral),
            const SizedBox(height: 18),
            const Text(
              'нет соединения',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _coralDeep,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'проверьте интернет и попробуйте ещё раз',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onRetry,
              child: const Text(
                'повторить',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClear,
              child: const Text(
                'очистить кэш и перезагрузить',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A8178)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Оверлей «страница не открылась»: показываем, когда сайт загрузился, но не
/// отрисовал контент (мёртвый WebView/протухшее состояние). Даём пользователю
/// выход прямо в приложении: очистить кэш и перезагрузить.
class _DeadPageScreen extends StatelessWidget {
  const _DeadPageScreen({
    required this.busy,
    required this.onClear,
    required this.onIgnore,
  });

  final bool busy;
  final Future<void> Function() onClear;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _beige,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, size: 56, color: _coral),
            const SizedBox(height: 18),
            const Text(
              'не удалось открыть',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _coralDeep,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'страница загрузилась не полностью. очистим кэш и '
              'попробуем заново — вход сохранится.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy ? null : onClear,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'очистить и перезагрузить',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : onIgnore,
              child: const Text(
                'оставить как есть',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A8178)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
