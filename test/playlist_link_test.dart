import 'package:flutter_test/flutter_test.dart';
import 'package:playlist_downloader/models/playlist_link.dart';

void main() {
  group('PlaylistSourceInfo.fromUri', () {
    test('recognizes supported service hosts only', () {
      expect(
        PlaylistSourceInfo.fromUri(
          Uri.parse('https://open.spotify.com/playlist/abc123'),
        ),
        PlaylistSource.spotify,
      );
      expect(
        PlaylistSourceInfo.fromUri(
          Uri.parse('https://music.youtube.com/playlist?list=PL123'),
        ),
        PlaylistSource.youtube,
      );
      expect(
        PlaylistSourceInfo.fromUri(
          Uri.parse('https://soundcloud.com/artist/sets/mix'),
        ),
        PlaylistSource.soundcloud,
      );
      expect(
        PlaylistSourceInfo.fromUri(
          Uri.parse('https://notyoutube.com/playlist?list=PL123'),
        ),
        isNull,
      );
    });
  });

  group('PlaylistSourceInfo.playlistLinkError', () {
    test('accepts supported playlist URL shapes', () {
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('https://open.spotify.com/playlist/abc123'),
          PlaylistSource.spotify,
        ),
        isNull,
      );
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('https://www.youtube.com/playlist?list=PL123'),
          PlaylistSource.youtube,
        ),
        isNull,
      );
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('https://soundcloud.com/artist/sets/mix'),
          PlaylistSource.soundcloud,
        ),
        isNull,
      );
    });

    test('rejects insecure and non-playlist links', () {
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('http://open.spotify.com/playlist/abc123'),
          PlaylistSource.spotify,
        ),
        isNotNull,
      );
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('https://open.spotify.com/track/abc123'),
          PlaylistSource.spotify,
        ),
        isNotNull,
      );
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('https://www.youtube.com/watch?v=video123'),
          PlaylistSource.youtube,
        ),
        isNotNull,
      );
      expect(
        PlaylistSourceInfo.playlistLinkError(
          Uri.parse('https://soundcloud.com/artist/track'),
          PlaylistSource.soundcloud,
        ),
        isNotNull,
      );
    });
  });

  test('playlist identity ignores source tracking parameters', () {
    final first = PlaylistLink(
      title: 'Mix',
      url: Uri.parse('https://www.youtube.com/playlist?list=PL123'),
      source: PlaylistSource.youtube,
    );
    final second = PlaylistLink(
      title: 'Same Mix',
      url: Uri.parse(
        'https://www.youtube.com/watch?v=video&list=PL123&si=tracking',
      ),
      source: PlaylistSource.youtube,
    );

    expect(first.identityKey, second.identityKey);
  });
}
