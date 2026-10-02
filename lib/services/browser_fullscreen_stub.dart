/// Native platforms use their window manager for fullscreen.
abstract final class BrowserFullscreen {
  static bool get isFullscreen => false;

  static Future<void> setFullscreen(bool value) async {}

  static void listen(void Function(bool) onChange) {}
}
