import 'dart:js_interop';

import 'package:flutter/widgets.dart';

import '../player.dart';
import 'player_web.dart';

Widget? buildWebVideoSurface(Player player) {
  if (player is! PlayerWeb || player.audioOnly) return null;
  return HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (element) => player.attach(element as JSObject),
  );
}
