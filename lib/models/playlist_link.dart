enum PlaylistSource { spotify, youtube, soundcloud }

extension PlaylistSourceInfo on PlaylistSource {
  String get label => switch (this) {
    PlaylistSource.spotify => 'Spotify',
    PlaylistSource.youtube => 'YouTube',
    PlaylistSource.soundcloud => 'SoundCloud',
  };

  static PlaylistSource? fromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'open.spotify.com' ||
        host == 'spotify.com' ||
        host == 'www.spotify.com') {
      return PlaylistSource.spotify;
    }
    if (host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com') {
      return PlaylistSource.youtube;
    }
    if (host == 'soundcloud.com' ||
        host == 'www.soundcloud.com' ||
        host == 'm.soundcloud.com' ||
        host == 'on.soundcloud.com') {
      return PlaylistSource.soundcloud;
    }
    return null;
  }

  static String? playlistLinkError(Uri uri, PlaylistSource source) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.port != 443) {
      return 'Use a secure HTTPS playlist link.';
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    switch (source) {
      case PlaylistSource.spotify:
        if (!segments.contains('playlist') ||
            segments.indexOf('playlist') == segments.length - 1) {
          return 'Use a Spotify playlist link, not a track or album link.';
        }
      case PlaylistSource.youtube:
        if (uri.queryParameters['list']?.isNotEmpty != true) {
          return 'Use a YouTube playlist link that includes a playlist ID.';
        }
      case PlaylistSource.soundcloud:
        if (uri.host.toLowerCase() != 'on.soundcloud.com' &&
            (segments.length < 3 || segments[1] != 'sets')) {
          return 'Use a SoundCloud playlist link with “/sets/” in its address.';
        }
    }
    return null;
  }
}

class PlaylistLink {
  const PlaylistLink({
    required this.title,
    required this.url,
    required this.source,
  });

  final String title;
  final Uri url;
  final PlaylistSource source;

  String get identityKey {
    switch (source) {
      case PlaylistSource.spotify:
        final segments = url.pathSegments;
        final playlistIndex = segments.indexOf('playlist');
        final id = playlistIndex >= 0 && playlistIndex + 1 < segments.length
            ? segments[playlistIndex + 1]
            : url.path;
        return 'spotify:$id';
      case PlaylistSource.youtube:
        return 'youtube:${url.queryParameters['list'] ?? url.toString()}';
      case PlaylistSource.soundcloud:
        final normalized = url.replace(
          host: url.host.toLowerCase(),
          query: null,
          fragment: null,
          path: url.path.replaceFirst(RegExp(r'/$'), ''),
        );
        return 'soundcloud:$normalized';
    }
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'url': url.toString(),
    'source': source.name,
  };

  factory PlaylistLink.fromJson(Map<String, dynamic> json) => PlaylistLink(
    title: json['title'] as String,
    url: Uri.parse(json['url'] as String),
    source: PlaylistSource.values.byName(json['source'] as String),
  );
}
