import 'playlist_link.dart';

class PlaylistTrackMetadata {
  const PlaylistTrackMetadata({
    required this.sourceItemId,
    required this.title,
    required this.sourceUrl,
    this.artistNames = const [],
    this.artworkUrl,
  });

  final String sourceItemId;
  final String title;
  final List<String> artistNames;
  final Uri sourceUrl;
  final Uri? artworkUrl;
}

class PlaylistMetadataSnapshot {
  const PlaylistMetadataSnapshot({
    required this.source,
    required this.sourcePlaylistId,
    required this.title,
    required this.sourceUrl,
    required this.fetchedAt,
    required this.tracks,
    this.artworkUrl,
  });

  final PlaylistSource source;
  final String sourcePlaylistId;
  final String title;
  final Uri sourceUrl;
  final Uri? artworkUrl;
  final DateTime fetchedAt;
  final List<PlaylistTrackMetadata> tracks;
}
