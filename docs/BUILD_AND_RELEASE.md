# Сборка и релиз

## Базовое окружение

- Flutter stable с Dart, совместимым с `sdk: ^3.12.0`.
- JDK 17.
- Android SDK/Android Studio.
- Для iOS: macOS, актуальный Xcode, CocoaPods и Ruby 3.3 для Fastlane CI.

Проверка:

```bash
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

## Android debug

```bash
flutter run
flutter build apk --debug
```

Результат: `build/app/outputs/flutter-apk/app-debug.apk`.

## Android release

Ключ подписи не хранится в репозитории. Получите `.jks`/`.keystore` отдельно, поместите вне Git и создайте `android/key.properties`:

```properties
storePassword=CHANGE_ME
keyPassword=CHANGE_ME
keyAlias=CHANGE_ME
storeFile=C:/absolute/secure/path/bembox-release.jks
```

Затем:

```bash
flutter build apk --release
flutter build appbundle --release
```

Перед публикацией обязательно проверьте подпись. Текущий `build.gradle.kts` при отсутствии `key.properties` подписывает release debug-ключом, поэтому успешная команда сама по себе не означает магазинный релиз. Это отмечено как технический долг.

RuStore Push использует разные project ID для debug и release, выбранные через manifest placeholder. Release push зависит от SHA сертификата, зарегистрированного в RuStore Console.

## iOS без подписи

```bash
flutter config --no-enable-swift-package-manager
flutter pub get
flutter build ios --release --no-codesign
```

SPM намеренно отключён в CI: текущая сборка Firebase через CocoaPods не подтягивает нежелательные рекламные компоненты/IDFA.

## TestFlight

Workflow `.github/workflows/testflight.yml` запускается вручную. Он:

1. использует macOS/Xcode;
2. создаёт временный `ios/private_keys/AuthKey.p8` из GitHub secret;
3. собирает iOS через CocoaPods;
4. запускает lane `beta` из `ios/fastlane/Fastfile`;
5. получает signing material через `match` из ветки `match-certs`;
6. загружает IPA в TestFlight.

Нужные GitHub secrets:

- `ASC_KEY_ID`;
- `ASC_ISSUER_ID`;
- `ASC_API_KEY_P8`;
- `IOS_TEAM_ID`;
- `MATCH_PASSWORD`.

Ни одного значения этих секретов в исходном пакете нет.

## App Store metadata

`.github/workflows/appstore-draft.yml` запускает Fastlane lane `draft` и загружает тексты/скриншоты без отправки на review. Метаданные лежат в `ios/fastlane/metadata/`, скриншоты — в `ios/fastlane/screenshots/`.

Важно: в `Fastfile` lane `draft` пока жёстко указан `app_version: "1.0.4"`, тогда как код имеет версию `1.0.5+6`. Перед следующим запуском синхронизировать версию.

## Версионирование

Версия задаётся один раз в `pubspec.yaml` как `major.minor.patch+build`, сейчас `1.0.5+6`. Для каждого магазинного релиза увеличивать build number; App Store и Google/RuStore не принимают повтор уже использованного номера.
