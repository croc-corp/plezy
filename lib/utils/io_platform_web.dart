import 'package:web/web.dart' as web;

/// Browser stand-in for `dart:io`'s `Platform`.
///
/// Every `is*` check is false, so web takes the same generic paths a platform
/// the app has no special handling for would; web-specific behavior keys off
/// `kIsWeb` instead.
abstract final class Platform {
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isMacOS = false;
  static const bool isWindows = false;
  static const bool isLinux = false;
  static const bool isFuchsia = false;

  static const String operatingSystem = 'web';
  static const String pathSeparator = '/';
  static const Map<String, String> environment = {};
  static const String resolvedExecutable = '';
  static const String version = '';

  static String get operatingSystemVersion => web.window.navigator.userAgent;
  static String get localHostname => web.window.location.hostname;
  static String get localeName => web.window.navigator.language;
  static int get numberOfProcessors => web.window.navigator.hardwareConcurrency;
}
