import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'source_dao.g.dart';

@DriftAccessor(tables: [SavedSources])
class SourceDao extends DatabaseAccessor<AppDatabase> with _$SourceDaoMixin {
  SourceDao(super.db);

  /// Sources saved while signed in as [accountEmail] — these are the links
  /// that auto-reconnect the next time this account signs in.
  Stream<List<SavedSource>> watchForAccount(String accountEmail) =>
      (select(savedSources)
            ..where((s) => s.accountEmail.equals(accountEmail))
            ..orderBy([(s) => OrderingTerm.desc(s.addedAt)]))
          .watch();

  /// Sources saved with no signed-in account (this device only).
  Stream<List<SavedSource>> watchDeviceOnly() =>
      (select(savedSources)
            ..where((s) => s.accountEmail.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.addedAt)]))
          .watch();

  Future<SavedSource> add({
    required TrackSourceType provider,
    required String rawLink,
    String? accountEmail,
    String? label,
  }) async {
    final row = SavedSourcesCompanion.insert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      provider: provider,
      rawLink: rawLink,
      accountEmail: Value(accountEmail),
      label: Value(label),
    );
    await into(savedSources).insert(row);
    return (select(savedSources)..where((s) => s.id.equals(row.id.value))).getSingle();
  }

  Future<void> remove(String id) =>
      (delete(savedSources)..where((s) => s.id.equals(id))).go();

  /// One-shot (non-stream) fetch used right after sign-in to decide which
  /// saved links need re-resolving into fresh Track rows.
  Future<List<SavedSource>> getForAccount(String accountEmail) =>
      (select(savedSources)..where((s) => s.accountEmail.equals(accountEmail))).get();
}
