import '../models/playlist_link.dart';
import '../models/playlist_metadata.dart';

abstract interface class PlaylistMetadataProvider {
  PlaylistSource get source;

  Future<PlaylistMetadataSnapshot> importPlaylist(Uri playlistUrl);
}

class MetadataImportException implements Exception {
  const MetadataImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
