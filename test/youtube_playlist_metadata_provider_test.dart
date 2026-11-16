import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playlist_downloader/data/playlist_metadata_provider.dart';
import 'package:playlist_downloader/data/youtube/youtube_playlist_metadata_provider.dart';
import 'package:playlist_downloader/models/playlist_link.dart';

void main() {
  const playlistUrl = 'https://www.youtube.com/playlist?list=PL_TEST';

  test('imports playlist and paginated items through the Data API', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['Cache-Control'], 'no-store');
      expect(request.url.queryParameters['key'], 'test-key');

      if (request.url.path.endsWith('/playlists')) {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'snippet': {
                  'title': 'Test Playlist',
                  'thumbnails': {
                    'high': {'url': 'https://i.ytimg.com/playlist.jpg'},
                  },
                },
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/playlistItems')) {
        final pageToken = request.url.queryParameters['pageToken'];
        if (pageToken == null) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'snippet': {
                    'title': 'First Track',
                    'videoOwnerChannelTitle': 'Artist One',
                    'resourceId': {'videoId': 'video-one'},
                    'thumbnails': {
                      'medium': {'url': 'https://i.ytimg.com/video-one.jpg'},
                    },
                  },
                },
              ],
              'nextPageToken': 'page-two',
            }),
            200,
          );
        }
        expect(pageToken, 'page-two');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'snippet': {
                  'title': 'Second Track',
                  'resourceId': {'videoId': 'video-two'},
                },
              },
            ],
          }),
          200,
        );
      }

      return http.Response('Unexpected request', 404);
    });

    final provider = YouTubePlaylistMetadataProvider(
      apiKey: 'test-key',
      client: client,
    );
    final snapshot = await provider.importPlaylist(Uri.parse(playlistUrl));
    provider.close();

    expect(requests, hasLength(3));
    expect(snapshot.source, PlaylistSource.youtube);
    expect(snapshot.sourcePlaylistId, 'PL_TEST');
    expect(snapshot.title, 'Test Playlist');
    expect(snapshot.tracks, hasLength(2));
    expect(snapshot.tracks.first.title, 'First Track');
    expect(snapshot.tracks.first.artistNames, ['Artist One']);
    expect(
      snapshot.tracks.first.sourceUrl,
      Uri.parse('https://www.youtube.com/watch?v=video-one'),
    );
    expect(snapshot.tracks.last.sourceItemId, 'video-two');
  });

  test('rejects links without a YouTube playlist ID', () async {
    final provider = YouTubePlaylistMetadataProvider(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      provider.importPlaylist(
        Uri.parse('https://www.youtube.com/watch?v=video'),
      ),
      throwsA(isA<MetadataImportException>()),
    );
    provider.close();
  });
}
