// Picks the right storage backend for the platform this app is running on,
// without any code elsewhere needing to know which one it got. Each variant
// exposes a single `QueryExecutor connect()`, wrapped in a LazyDatabase so
// opening (which is async on every platform, not just web) doesn't block
// constructing AppDatabase.
//
// - Desktop/mobile (dart:io available): a real native SQLite file via
//   NativeDatabase, run on a background isolate.
// - Web (dart.library.js_interop available): drift's WASM-based sqlite,
//   backed by IndexedDB/OPFS. Requires sqlite3.wasm + drift_worker.js to be
//   present in web/ — see README.md "Web build setup".
//
// This conditional-import pattern is the one drift's own docs recommend for
// "run on every platform including web" apps.
export 'unsupported.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
