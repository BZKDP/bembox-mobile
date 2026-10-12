pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP понижен с 9.0.1 до 8.9.1: AGP 9.0 сделал getDefaultProguardFile(
    // 'proguard-android.txt') жёсткой ошибкой, а flutter_inappwebview 6.1.5
    // (android 1.1.3) всё ещё его использует (issue pichillilorenzo #2765,
    // не пофикшен в стабильной версии). 8.9.1 — минимум, которого требуют
    // транзитивные androidx-зависимости, и при этом ещё < 9.0 (без жёсткой
    // ошибки proguard). Вернуть на 9.x — после релиза фикса плагина.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Google Services: обрабатывает google-services.json (FCM/Firebase).
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
