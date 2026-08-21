import '../db/app_database.dart';

extension TrackX on Track {
  Duration get duration => Duration(milliseconds: durationMs);
}
