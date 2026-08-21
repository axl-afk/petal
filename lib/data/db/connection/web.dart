import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

// Web storage for Petal's library database.
//
// This needs `sqlite3.wasm` and `drift_worker.js` copied into web/ before
// `flutter build web` / `flutter run -d chrome` — see README.md "Web build
// setup" for the exact commands. drift's web-support API has moved around a
// bit across versions; if this file doesn't compile against whatever drift
// version pub resolves for you, check https://drift.simonbinder.eu/web/ for
// the current shape of WasmDatabase.open — the concept (open a wasm sqlite
// backed by IndexedDB/OPFS) will be the same even if an exact name shifted.
QueryExecutor connect() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'petal_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      // Non-fatal: drift falls back to a slower storage strategy
      // automatically. Surfaced here only for debugging.
      // ignore: avoid_print
      print('Petal: web database missing features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}
