import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Runs [computation] in a background isolate via [Isolate.run].
///
/// Falls back to synchronous execution when the isolate infrastructure is
/// unavailable (e.g. iOS killed background isolates while the app was
/// suspended). The web has no isolates at all, so it always runs inline.
Future<R> tryIsolateRun<R>(R Function() computation) async {
  if (kIsWeb) return computation();
  try {
    return await Isolate.run(computation);
  } on StateError {
    return computation();
  } on ArgumentError catch (e) {
    if (!e.toString().contains('Illegal argument in isolate message')) rethrow;
    return computation();
  }
}
