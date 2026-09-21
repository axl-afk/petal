import '../db/app_database.dart';
import '../../utils/metadata_text.dart';

extension TrackX on Track {
  Duration get duration => Duration(milliseconds: durationMs);
  String get displayTitle => cleanMetadataText(title);
  String get displayArtist => cleanMetadataText(artist);
  String get displayAlbum => cleanMetadataText(album);
  String get displayGenre => cleanMetadataText(genre);
}
