import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playlist_downloader/data/playlist_link_repository.dart';
import 'package:playlist_downloader/main.dart';
import 'package:playlist_downloader/models/playlist_link.dart';

void main() {
  testWidgets('library screen shows its empty state and rights note', (
    tester,
  ) async {
    await tester.pumpWidget(
      TrackNestApp(repository: _FakePlaylistLinkRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your library is ready'), findsOneWidget);
    expect(find.text('Audio downloads are unavailable'), findsOneWidget);
  });

  testWidgets('saved playlist can be searched by its local name', (
    tester,
  ) async {
    final repository = _FakePlaylistLinkRepository([
      PlaylistLink(
        title: 'Focus Mix',
        url: Uri.parse('https://open.spotify.com/playlist/abc123'),
        source: PlaylistSource.spotify,
      ),
      PlaylistLink(
        title: 'Weekend Drive',
        url: Uri.parse('https://open.spotify.com/playlist/def456'),
        source: PlaylistSource.spotify,
      ),
    ]);

    await tester.pumpWidget(TrackNestApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Focus Mix'), findsOneWidget);
    expect(find.text('Weekend Drive'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'focus');
    await tester.pumpAndSettle();

    expect(find.text('Focus Mix'), findsOneWidget);
    expect(find.text('Weekend Drive'), findsNothing);
  });
}

class _FakePlaylistLinkRepository extends PlaylistLinkRepository {
  _FakePlaylistLinkRepository([Iterable<PlaylistLink> initialLinks = const []])
    : links = List.of(initialLinks);

  List<PlaylistLink> links;

  @override
  Future<List<PlaylistLink>> load() async => List.of(links);

  @override
  Future<void> saveAll(Iterable<PlaylistLink> links) async {
    this.links = List.of(links);
  }
}
