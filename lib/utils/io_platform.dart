/// `dart:io`'s [Platform] on native hosts, and a browser stand-in on the web,
/// where every `dart:io` Platform getter throws `UnsupportedError`.
///
/// Import this instead of `dart:io` for [Platform]; files that need the rest
/// of `dart:io` import it with `hide Platform`. `scripts/web/codemod.py`
/// rewrites upstream imports into this form.
library;

export 'io_platform_web.dart' if (dart.library.io) 'io_platform_native.dart';
