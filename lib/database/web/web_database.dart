import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import '../../utils/app_logger.dart';

/// Opens the app database in the browser.
///
/// drift picks the most durable storage the browser offers (OPFS in a shared
/// or dedicated worker, IndexedDB otherwise). `sqlite3.wasm` and
/// `drift_worker.js` are placed next to `index.html` by `scripts/web/build.sh`.
QueryExecutor openWebDatabase() => LazyDatabase(() async {
  final result = await WasmDatabase.open(
    databaseName: 'plezy_downloads',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  appLogger.i(
    'Web database opened',
    error: {
      'implementation': result.chosenImplementation.name,
      if (result.missingFeatures.isNotEmpty) 'missingFeatures': result.missingFeatures.map((f) => f.name).join(','),
    },
  );
  return result.resolvedExecutor;
});
