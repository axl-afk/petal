// Local-file import needs real filesystem access — copying picked files
// into app storage, recursively scanning folders, reading embedded tags —
// none of which exists (or compiles) on web. Exports the real dart:io-backed
// implementation everywhere it's available, and a web stub (never actually
// called, thanks to the kIsWeb guards in LibraryController, but which must
// still exist and compile since providers.dart constructs a LocalFileService
// unconditionally on every platform) on web specifically.
//
// Same pattern as data/db/connection/connection.dart, which drift's own
// docs recommend for "runs on every platform including web" code.
export 'local_file_service_web.dart' if (dart.library.io) 'local_file_service_io.dart';
