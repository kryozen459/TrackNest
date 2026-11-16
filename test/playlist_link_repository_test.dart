import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playlist_downloader/data/playlist_link_repository.dart';
import 'package:playlist_downloader/models/playlist_link.dart';

void main() {
  late Directory testDirectory;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp('tracknest_store_');
  });

  tearDown(() async {
    await testDirectory.delete(recursive: true);
  });

  test('saves playlist links to a local file and reloads them', () async {
    final firstRepository = PlaylistLinkRepository(directory: testDirectory);
    final playlist = PlaylistLink(
      title: 'After Hours',
      url: Uri.parse('https://open.spotify.com/playlist/abc'),
      source: PlaylistSource.spotify,
    );

    await firstRepository.saveAll([playlist]);
    final loaded = await PlaylistLinkRepository(directory: testDirectory)
        .load();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, playlist.title);
    expect(loaded.single.url, playlist.url);
    expect(loaded.single.source, playlist.source);
  });

  test('returns an empty library when the local file does not exist', () async {
    final loaded = await PlaylistLinkRepository(directory: testDirectory)
        .load();

    expect(loaded, isEmpty);
  });
}
