import 'package:drift/drift.dart';

/// Native stand-in; see `web_database.dart`.
QueryExecutor openWebDatabase() => throw UnsupportedError('openWebDatabase is only available on the web');
