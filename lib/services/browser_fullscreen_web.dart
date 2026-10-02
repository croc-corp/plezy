import 'dart:js_interop';

import 'package:web/web.dart' as web;

abstract final class BrowserFullscreen {
  static web.EventListener? _listener;

  static bool get isFullscreen => web.document.fullscreenElement != null;

  static Future<void> setFullscreen(bool value) async {
    if (value == isFullscreen) return;
    if (value) {
      await web.document.documentElement!.requestFullscreen().toDart;
    } else {
      await web.document.exitFullscreen().toDart;
    }
  }

  static void listen(void Function(bool) onChange) {
    if (_listener != null) return;
    _listener = ((web.Event _) => onChange(isFullscreen)).toJS;
    web.document.addEventListener('fullscreenchange', _listener);
    onChange(isFullscreen);
  }
}
