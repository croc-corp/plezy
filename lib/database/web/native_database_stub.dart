import 'dart:io' show File;

import 'package:drift/drift.dart';

/// Web stand-in for `package:drift/native.dart`, which needs `dart:ffi`.
/// The web build opens its database through `openWebDatabase` instead.
abstract final class NativeDatabase {
  static QueryExecutor createInBackground(File file, {void Function(dynamic db)? setup}) =>
      throw UnsupportedError('NativeDatabase is not available on the web');
}
