import '../models/playlist_link.dart';

enum AudioExportStatus {
  disabledBySourcePolicy,
  requiresRightsHolderAuthorization,
  notReviewed,
}

class SourceCapability {
  const SourceCapability({
    required this.metadataAvailable,
    required this.authorizationNote,
    required this.audioExportStatus,
  });

  final bool metadataAvailable;
  final String authorizationNote;
  final AudioExportStatus audioExportStatus;
}

const sourceCapabilities = <PlaylistSource, SourceCapability>{
  PlaylistSource.spotify: SourceCapability(
    metadataAvailable: false,
    authorizationNote: 'OAuth is required. Playlist item details are currently available only for playlists owned by or shared with the authorizing user.',
    audioExportStatus: AudioExportStatus.disabledBySourcePolicy,
  ),
  PlaylistSource.youtube: SourceCapability(
    metadataAvailable: true,
    authorizationNote: 'Public playlist metadata can use an API key; user-specific data requires OAuth. API data must be refreshed or deleted within 30 days.',
    audioExportStatus: AudioExportStatus.disabledBySourcePolicy,
  ),
  PlaylistSource.soundcloud: SourceCapability(
    metadataAvailable: false,
    authorizationNote: 'A registered API application is required. Current API terms prohibit offline access to SoundCloud user content, including tracks marked downloadable.',
    audioExportStatus: AudioExportStatus.disabledBySourcePolicy,
  ),
};
