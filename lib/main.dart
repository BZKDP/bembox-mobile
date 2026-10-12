import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/crash_reporter.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'push/fcm_service.dart';
import 'shell/webview_shell.dart';

const _beige = Color(0xFFFFFCF6);
const _onboardingKey = 'bem-onboarding-done';
const _lastBuildKey = 'bem-last-build';

/// Точка входа тонкой нативной оболочки bembox (full-screen WebView поверх
/// bembox.ru) с нативным онбордингом при первом запуске.
Future<void> main() async {
  // Всё приложение в защищённой зоне: любые необработанные ошибки (sync/async)
  // ловит CrashReporter, а не «тихий» крэш процесса.
  runZonedGuarded(_bootstrap, (error, stack) => CrashReporter.record(error, stack));
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporter.install();

  // Firebase / FCM (iOS + Android-Play). На устройствах без Google Play Services
  // токен не выдаётся — там работает RuStore-канал; всё под try, чтобы это не
  // ломало запуск приложения.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(bemboxFcmBackgroundHandler);
  } catch (_) {}

  // Жёсткая портретная блокировка (дублирует манифест/Info.plist).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Системные панели под бренд.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFCF6),
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0xFFFFFCF6),
    ),
  );

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  // Нативный онбординг показываем при первом запуске на обеих платформах
  // (iOS и Android) — единый первый опыт для пользователя.
  final prefs = await SharedPreferences.getInstance();

  // Авто-лечение при обновлении приложения: чистим веб-кэш/хранилище WebView
  // ДО первой загрузки сайта. Делаем здесь (в bootstrap), а не в оболочке,
  // чтобы успеть до старта WebView — иначе текущая загрузка пойдёт по старому кэшу.
  await _healWebStateOnUpgrade(prefs);

  final done = prefs.getBool(_onboardingKey) ?? false;
  final showOnboarding = !done;

  runApp(BemboxShellApp(showOnboarding: showOnboarding));
}

/// Когда пользователь обновляет приложение (новая версия из стора), один раз
/// чистим HTTP-кэш WebView и web-storage (localStorage/IndexedDB). Зачем: сайт
/// bembox.ru — живой, и после его обновления у WebView может «залипнуть»
/// протухшее локальное состояние от старой версии (белый экран / мёртвые
/// кнопки, которые не лечатся перезапуском). Куки-сессию НЕ трогаем
/// (на Android web-storage и куки раздельны) → пользователь остаётся залогинен.
/// Срабатывает ровно один раз на каждую новую сборку (сравнение с сохранённой).
Future<void> _healWebStateOnUpgrade(SharedPreferences prefs) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final current = '${info.version}+${info.buildNumber}';
    final last = prefs.getString(_lastBuildKey);
    // last == null → самая первая установка: чистить нечего, просто запоминаем.
    if (last != null && last != current) {
      await InAppWebViewController.clearAllCache();
      // localStorage/IndexedDB чистим только на Android: там это не затрагивает
      // куки (логин жив). На iOS deleteAllData может задеть и куки → пропускаем,
      // чтобы не разлогинивать; на iOS достаточно сброса HTTP-кэша выше.
      if (Platform.isAndroid) {
        await WebStorageManager.instance().deleteAllData();
      }
    }
    await prefs.setString(_lastBuildKey, current);
  } catch (e, s) {
    // Лечение — не критичный путь: его сбой не должен мешать запуску.
    CrashReporter.record(e, s, source: 'heal-upgrade');
  }
}

class BemboxShellApp extends StatefulWidget {
  const BemboxShellApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

  @override
  State<BemboxShellApp> createState() => _BemboxShellAppState();
}

class _BemboxShellAppState extends State<BemboxShellApp> {
  late bool _onboarding = widget.showOnboarding;

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (mounted) setState(() => _onboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bembox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7547),
          primary: const Color(0xFFFF7547),
        ),
        scaffoldBackgroundColor: _beige,
      ),
      home: _onboarding ? OnboardingScreen(onFinish: _finishOnboarding) : const WebViewShell(),
    );
  }
}
