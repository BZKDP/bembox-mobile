import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // Google Services — обрабатывает google-services.json для FCM/Firebase.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Релизная подпись: читаем секреты из android/key.properties (НЕ коммитить!).
// Шаблон — android/key.properties.example. Если файла нет (напр. чужая машина) —
// release падёт обратно на debug-подпись.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.evgeniishvydchenko.bembox"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion НЕ задаём намеренно: ни один из наших плагинов не использует
    // нативный C/C++ (NDK), а объявленный ndkVersion заставляет Android Gradle
    // Plugin провижинить/скачивать NDK при конфигурации — на нестабильной сети
    // он качался битым (CXX1101: нет source.properties). Если позже появится
    // плагин с нативным кодом — вернём строку `ndkVersion = flutter.ndkVersion`
    // и установим NDD корректно через sdkmanager.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.evgeniishvydchenko.bembox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // RuStore Push Project ID по умолчанию = проект с debug-SHA (для debug-
        // сборок и нашей отладки). release переопределяет ниже.
        manifestPlaceholders["rustorePushProjectId"] = "YOUR_RUSTORE_PUSH_PROJECT_ID_DEBUG"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Релизный ключ bembox (RuStore). Если key.properties нет — debug.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // RuStore push-проект с release-SHA (боевой, production-сборка).
            manifestPlaceholders["rustorePushProjectId"] = "YOUR_RUSTORE_PUSH_PROJECT_ID_RELEASE"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Нужен напрямую: наш BemboxPushService наследует RuStoreMessagingService.
    implementation("ru.rustore.sdk:pushclient:6.10.0")
}
