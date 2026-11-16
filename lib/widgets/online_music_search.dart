import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_windows/webview_windows.dart';

import '../data/youtube/youtube_api_key_store.dart';
import '../data/youtube/youtube_search_provider.dart';
import '../platform/windows_link_opener.dart';
import 'glass_surface.dart';

class OnlineMusicSearch extends StatefulWidget {
  const OnlineMusicSearch({super.key});

  @override
  State<OnlineMusicSearch> createState() => _OnlineMusicSearchState();
}

class _OnlineMusicSearchState extends State<OnlineMusicSearch> {
  final TextEditingController _queryController = TextEditingController();
  final YouTubeApiKeyStore _apiKeyStore = YouTubeApiKeyStore();
  final List<YouTubeSearchResult> _results = [];

  WebviewController? _webviewController;
  StreamSubscription<LoadingState>? _loadingSubscription;
  StreamSubscription<WebErrorStatus>? _errorSubscription;
  Future<bool>? _webviewInitialization;
  YouTubeSearchResult? _selectedResult;
  String? _apiKey;
  String? _message;
  bool _loadingKey = true;
  bool _searching = false;
  bool _webviewReady = false;
  bool _webviewLoading = false;
  bool _websiteSearch = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadApiKey());
  }

  @override
  void dispose() {
    _queryController.dispose();
    unawaited(_loadingSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    final controller = _webviewController;
    if (controller != null) unawaited(_disposeWebview(controller));
    super.dispose();
  }

  Future<void> _disposeWebview(WebviewController controller) async {
    try {
      await controller.dispose();
    } catch (_) {
      // The embedded browser can fail to initialize when WebView2 is missing.
    }
  }

  Future<void> _loadApiKey() async {
    try {
      final apiKey = await _apiKeyStore.load();
      if (mounted) setState(() => _apiKey = apiKey);
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'TrackNest could not load your YouTube search settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingKey = false);
    }
  }

  Future<bool> _ensureWebview() async {
    if (_webviewReady) return true;
    final activeInitialization = _webviewInitialization;
    if (activeInitialization != null) return activeInitialization;

    final initialization = _initializeWebview();
    _webviewInitialization = initialization;
    final ready = await initialization;
    _webviewInitialization = null;
    return ready;
  }

  Future<bool> _initializeWebview() async {
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        throw const _OnlineMusicException(
          'The Microsoft Edge WebView2 Runtime is missing. Install it, then reopen TrackNest.',
        );
      }

      final controller = WebviewController();
      _webviewController = controller;
      await controller.initialize();
      await controller.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.sameWindow,
      );
      _loadingSubscription = controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() => _webviewLoading = state == LoadingState.loading);
      });
      _errorSubscription = controller.onLoadError.listen((_) {
        if (!mounted) return;
        setState(() {
          _webviewLoading = false;
          _message = 'Could not load online music. Check your internet connection and try again.';
        });
      });
      if (mounted) setState(() => _webviewReady = true);
      return true;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _webviewLoading = false;
          _message =
              error.message ??
              'TrackNest could not start its online music player.';
        });
      }
    } on _OnlineMusicException catch (error) {
      if (mounted) {
        setState(() {
          _webviewLoading = false;
          _message = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _webviewLoading = false;
          _message = 'TrackNest could not start its online music player.';
        });
      }
    }
    return false;
  }

  Future<void> _search() async {
    if (_loadingKey || _searching) return;
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _message = 'Type a song or artist to search.');
      return;
    }

    setState(() {
      _message = null;
      _selectedResult = null;
      _results.clear();
      _searching = true;
      _websiteSearch = _apiKey == null;
    });

    if (_apiKey == null) {
      final ready = await _ensureWebview();
      if (!ready || !mounted) {
        if (mounted) setState(() => _searching = false);
        return;
      }
      try {
        final uri = Uri.https('music.youtube.com', '/search', {'q': query});
        await _webviewController!.loadUrl(uri.toString());
      } catch (_) {
        if (mounted) {
          setState(() {
            _message =
                'Could not open YouTube Music. Check your internet connection.';
          });
        }
      } finally {
        if (mounted) setState(() => _searching = false);
      }
      return;
    }

    final provider = YouTubeSearchProvider(apiKey: _apiKey!);
    try {
      final results = await provider.search(query);
      if (!mounted) return;
      setState(() {
        _results.addAll(results);
        if (results.isEmpty) _message = 'No matching songs were found.';
      });
    } on YouTubeSearchException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on http.ClientException {
      if (mounted) {
        setState(
          () => _message =
              'Could not search YouTube. Check your internet connection.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'YouTube search failed. Check your API key and try again.',
        );
      }
    } finally {
      provider.close();
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _playResult(YouTubeSearchResult result) async {
    setState(() {
      _selectedResult = result;
      _websiteSearch = false;
      _message = null;
      _webviewLoading = true;
    });
    final ready = await _ensureWebview();
    if (!ready || !mounted) return;
    try {
      final uri = Uri.https(
        'www.youtube-nocookie.com',
        '/embed/${result.videoId}',
        {'autoplay': '1', 'controls': '1', 'playsinline': '1', 'rel': '0'},
      );
      await _webviewController!.loadUrl(uri.toString());
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Could not start this song. Try another search result.';
          _webviewLoading = false;
        });
      }
    }
  }

  Future<void> _editApiKey() async {
    final keyController = TextEditingController(text: _apiKey ?? '');
    final apiKey = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TrackNest search setup'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a YouTube Data API key to show search results directly in TrackNest. Without a key, searches open inside YouTube Music instead.',
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => unawaited(
                  openExternalUrl(
                    Uri.https('console.cloud.google.com', '/apis/credentials'),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open Google Cloud Console'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: keyController,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'YouTube Data API key',
                  hintText: 'Paste your API key',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => Navigator.pop(context, value.trim()),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable YouTube Data API v3 for the Google Cloud project that owns this key.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Use YouTube Music search'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, keyController.text.trim()),
            child: const Text('Save key'),
          ),
        ],
      ),
    );
    keyController.dispose();
    if (apiKey == null || !mounted) return;

    try {
      if (apiKey.isEmpty) {
        await _apiKeyStore.save('');
        setState(() => _apiKey = null);
      } else {
        await _apiKeyStore.save(apiKey);
        setState(() {
          _apiKey = apiKey;
          _message = 'TrackNest search is ready. Search for a song above.';
        });
      }
    } on FileSystemException {
      if (mounted) {
        setState(
          () => _message = 'Could not save your search settings on this PC.',
        );
      }
    }
  }

  Widget _searchResults() {
    final colors = Theme.of(context).colorScheme;
    if (_results.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 388),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _results.length,
        separatorBuilder: (_, _) => Divider(color: colors.outlineVariant),
        itemBuilder: (context, index) {
          final result = _results[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 94,
                height: 54,
                child: result.thumbnailUrl == null
                    ? ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.music_note, color: colors.primary),
                      )
                    : Image.network(
                        result.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child: Icon(Icons.music_note, color: colors.primary),
                        ),
                      ),
              ),
            ),
            title: Text(
              result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              result.channel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton.filledTonal(
              tooltip: 'Play ${result.title}',
              onPressed: () => unawaited(_playResult(result)),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showWebview = _websiteSearch || _selectedResult != null;

    return GlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      radius: 20,
      tint: const Color(0xFFB88AFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.language_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stream music online',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Search songs and play them over the internet.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Search settings',
                onPressed: _loadingKey ? null : _editApiKey,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'Online streams play inside TrackNest and are not saved to this PC.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_search()),
                  decoration: InputDecoration(
                    hintText: 'Search for a song or artist',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                              _queryController.clear();
                              _results.clear();
                              _message = null;
                            }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _loadingKey || _searching ? null : _search,
                icon: _searching
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(
                color: _message!.startsWith('TrackNest search is ready')
                    ? colors.primary
                    : colors.error,
              ),
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 10),
            _searchResults(),
          ],
          if (_selectedResult case final result?) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 390,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_webviewReady && _webviewController != null)
                      Webview(_webviewController!)
                    else
                      ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    if (_webviewLoading)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Now playing: ${result.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (_websiteSearch) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 520,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_webviewReady && _webviewController != null)
                      Webview(_webviewController!)
                    else
                      ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Center(
                          child: _message == null
                              ? const CircularProgressIndicator()
                              : Text(
                                  _message!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.error),
                                ),
                        ),
                      ),
                    if (_webviewLoading)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (!showWebview && _results.isEmpty && _message == null) ...[
            const SizedBox(height: 14),
            Text(
              _apiKey == null
                  ? 'Search opens YouTube Music here. Add a YouTube API key in settings for TrackNest search results.'
                  : 'Search results will appear here. Choose a song to start the embedded player.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnlineMusicException implements Exception {
  const _OnlineMusicException(this.message);

  final String message;
}
