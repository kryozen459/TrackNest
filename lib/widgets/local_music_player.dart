import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';

class _PlaybackPreparationException implements Exception {
  const _PlaybackPreparationException(this.message);

  final String message;
}

@immutable
class LocalPlaybackSnapshot {
  const LocalPlaybackSnapshot({
    this.title,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = .78,
    this.isPlaying = false,
    this.isBusy = false,
    this.isShuffleEnabled = false,
  });

  final String? title;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isPlaying;
  final bool isBusy;
  final bool isShuffleEnabled;
}

class LocalPlaybackController extends ChangeNotifier {
  LocalPlaybackSnapshot _snapshot = const LocalPlaybackSnapshot();
  Future<void> Function()? _onPrevious;
  Future<void> Function()? _onToggle;
  Future<void> Function()? _onNext;
  VoidCallback? _onToggleShuffle;
  Future<void> Function(Duration)? _onSeek;
  Future<void> Function(double)? _onVolumeChanged;

  LocalPlaybackSnapshot get snapshot => _snapshot;

  void attach({
    required Future<void> Function() onPrevious,
    required Future<void> Function() onToggle,
    required Future<void> Function() onNext,
    required VoidCallback onToggleShuffle,
    required Future<void> Function(Duration) onSeek,
    required Future<void> Function(double) onVolumeChanged,
  }) {
    _onPrevious = onPrevious;
    _onToggle = onToggle;
    _onNext = onNext;
    _onToggleShuffle = onToggleShuffle;
    _onSeek = onSeek;
    _onVolumeChanged = onVolumeChanged;
  }

  void detach() {
    _onPrevious = null;
    _onToggle = null;
    _onNext = null;
    _onToggleShuffle = null;
    _onSeek = null;
    _onVolumeChanged = null;
  }

  void publish(LocalPlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> previous() async {
    await _onPrevious?.call();
  }

  Future<void> toggle() async {
    await _onToggle?.call();
  }

  Future<void> next() async {
    await _onNext?.call();
  }

  void toggleShuffle() {
    _onToggleShuffle?.call();
  }

  Future<void> seek(Duration position) async {
    await _onSeek?.call(position);
  }

  Future<void> setVolume(double volume) async {
    await _onVolumeChanged?.call(volume);
  }
}

class LocalNowPlayingBar extends StatefulWidget {
  const LocalNowPlayingBar({super.key, required this.controller});

  final LocalPlaybackController controller;

  @override
  State<LocalNowPlayingBar> createState() => _LocalNowPlayingBarState();
}

class _LocalNowPlayingBarState extends State<LocalNowPlayingBar> {
  Duration? _scrubbingPosition;

  String _timeLabel(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Widget _progressSlider(LocalPlaybackSnapshot snapshot) {
    final durationMs = snapshot.duration.inMilliseconds;
    final position = _scrubbingPosition ?? snapshot.position;
    final positionMs = position.inMilliseconds.clamp(0, max(1, durationMs));
    return Slider(
      value: durationMs == 0 ? 0 : positionMs.toDouble(),
      max: durationMs > 0 ? durationMs.toDouble() : 1,
      onChanged: durationMs == 0
          ? null
          : (value) => setState(
              () => _scrubbingPosition = Duration(milliseconds: value.round()),
            ),
      onChangeEnd: durationMs == 0
          ? null
          : (value) {
              final position = Duration(milliseconds: value.round());
              setState(() => _scrubbingPosition = null);
              unawaited(widget.controller.seek(position));
            },
    );
  }

  Widget _volumeSlider(LocalPlaybackSnapshot snapshot, {double width = 120}) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          IconButton(
            tooltip: snapshot.volume == 0 ? 'Unmute' : 'Mute',
            onPressed: () => unawaited(
              widget.controller.setVolume(snapshot.volume == 0 ? .78 : 0),
            ),
            icon: Icon(
              snapshot.volume == 0
                  ? Icons.volume_off_rounded
                  : snapshot.volume < .5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Slider(
              value: snapshot.volume.clamp(0.0, 1.0).toDouble(),
              onChanged: (value) =>
                  unawaited(widget.controller.setVolume(value)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transport(LocalPlaybackSnapshot snapshot) {
    final hasSong = snapshot.title != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: snapshot.isShuffleEnabled
              ? 'Turn shuffle off'
              : 'Shuffle songs',
          onPressed: widget.controller.toggleShuffle,
          color: snapshot.isShuffleEnabled
              ? Theme.of(context).colorScheme.primary
              : null,
          icon: const Icon(Icons.shuffle_rounded),
        ),
        IconButton(
          tooltip: 'Previous song',
          onPressed: !hasSong || snapshot.isBusy
              ? null
              : () => unawaited(widget.controller.previous()),
          icon: const Icon(Icons.skip_previous_rounded, size: 27),
        ),
        IconButton.filled(
          tooltip: snapshot.isPlaying ? 'Pause' : 'Play',
          onPressed: !hasSong || snapshot.isBusy
              ? null
              : () => unawaited(widget.controller.toggle()),
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
          icon: snapshot.isBusy
              ? const SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  snapshot.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 27,
                ),
        ),
        IconButton(
          tooltip: 'Next song',
          onPressed: !hasSong || snapshot.isBusy
              ? null
              : () => unawaited(widget.controller.next()),
          icon: const Icon(Icons.skip_next_rounded, size: 27),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snapshot = widget.controller.snapshot;
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: GlassSurface(
                width: double.infinity,
                radius: 20,
                tint: const Color(0xFF45CDB8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 820;
                    final title =
                        snapshot.title ?? 'Choose a song from Your music';
                    final subtitle = snapshot.title == null
                        ? 'Your player is ready'
                        : snapshot.isPlaying
                        ? 'Playing from this PC'
                        : 'Paused';
                    final cover = Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: colors.onPrimary,
                      ),
                    );
                    final trackInfo = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    );
                    final progress = Row(
                      children: [
                        Text(
                          _timeLabel(_scrubbingPosition ?? snapshot.position),
                        ),
                        Expanded(child: _progressSlider(snapshot)),
                        Text(_timeLabel(snapshot.duration)),
                      ],
                    );

                    if (compact) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              cover,
                              const SizedBox(width: 11),
                              Expanded(child: trackInfo),
                              _transport(snapshot),
                            ],
                          ),
                          progress,
                          Align(
                            alignment: Alignment.centerRight,
                            child: _volumeSlider(snapshot, width: 180),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        cover,
                        const SizedBox(width: 11),
                        Expanded(flex: 2, child: trackInfo),
                        _transport(snapshot),
                        const SizedBox(width: 14),
                        Expanded(flex: 3, child: progress),
                        _volumeSlider(snapshot, width: 170),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LocalMusicPlayer extends StatefulWidget {
  const LocalMusicPlayer({super.key, required this.controller});

  final LocalPlaybackController controller;

  @override
  State<LocalMusicPlayer> createState() => _LocalMusicPlayerState();
}

class _LocalMusicPlayerState extends State<LocalMusicPlayer> {
  static const MethodChannel _channel = MethodChannel(
    'tracknest/audio_converter',
  );

  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final Random _random = Random();
  final List<String> _songs = [];
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<PlayerState> _stateSubscription;
  late final StreamSubscription<void> _completionSubscription;
  late final StreamSubscription<AudioEvent> _playerErrorSubscription;

  int? _currentIndex;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _loading = true;
  bool _shuffle = false;
  bool _repeatAll = false;
  bool _working = false;
  double _volume = .78;
  String _query = '';
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _attachController();
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
      _publishPlayback();
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
      _publishPlayback();
    });
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
      _publishPlayback();
    });
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      unawaited(_advanceAfterCompletion());
    });
    _playerErrorSubscription = _player.eventStream.listen(
      (_) {},
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _message = 'TrackNest could not start this audio file. Try another file format.';
          _messageIsError = true;
        });
        _publishPlayback();
      },
    );
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    unawaited(_player.setVolume(_volume));
    unawaited(_loadLibrary());
  }

  @override
  void didUpdateWidget(covariant LocalMusicPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      _attachController();
    }
  }

  void _attachController() {
    widget.controller.attach(
      onPrevious: _skipPrevious,
      onToggle: _togglePlayback,
      onNext: _skipNext,
      onToggleShuffle: _toggleShuffle,
      onSeek: _seekTo,
      onVolumeChanged: _setVolume,
    );
  }

  void _publishPlayback() {
    final path = _currentIndex == null || _currentIndex! >= _songs.length
        ? null
        : _songs[_currentIndex!];
    widget.controller.publish(
      LocalPlaybackSnapshot(
        title: path == null ? null : _titleFor(path),
        position: _position,
        duration: _duration ?? Duration.zero,
        volume: _volume,
        isPlaying: _playing,
        isBusy: _working,
        isShuffleEnabled: _shuffle,
      ),
    );
  }

  void _toggleShuffle() {
    setState(() => _shuffle = !_shuffle);
    _publishPlayback();
  }

  @override
  void dispose() {
    widget.controller.detach();
    _searchController.dispose();
    unawaited(_positionSubscription.cancel());
    unawaited(_durationSubscription.cancel());
    unawaited(_stateSubscription.cancel());
    unawaited(_completionSubscription.cancel());
    unawaited(_playerErrorSubscription.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<File> _libraryFile() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw const FileSystemException(
        'TrackNest could not find the Windows app data folder.',
      );
    }
    final directory = Directory('$appData${Platform.pathSeparator}TrackNest');
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}local_music_v1.json',
    );
  }

  Future<void> _loadLibrary() async {
    try {
      final file = await _libraryFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          _songs.addAll(decoded.whereType<String>());
        }
      }
    } catch (_) {
      _message = 'Could not load the music library saved on this PC.';
      _messageIsError = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLibrary() async {
    final file = await _libraryFile();
    await file.writeAsString(jsonEncode(_songs), flush: true);
  }

  Future<String> _resolvePlaybackPath(String sourcePath) async {
    final extension = sourcePath.split('.').last.toLowerCase();
    const videoExtensions = {
      'mp4',
      'm4v',
      'mov',
      'webm',
      'mkv',
      'avi',
      'wmv',
      'flv',
    };
    if (!videoExtensions.contains(extension)) return sourcePath;

    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw const _PlaybackPreparationException(
        'TrackNest could not find the Windows app data folder.',
      );
    }

    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final ffmpeg = File(
      '${executableDirectory.path}${Platform.pathSeparator}'
      'media-tools${Platform.pathSeparator}ffmpeg.exe',
    );
    if (!await ffmpeg.exists()) {
      throw const _PlaybackPreparationException(
        'TrackNest’s playback tools are missing. Reopen the complete app folder and try again.',
      );
    }

    final source = File(sourcePath);
    final sourceStat = await source.stat();
    var pathHash = 0x811c9dc5;
    for (final byte in utf8.encode(sourcePath.toLowerCase())) {
      pathHash = ((pathHash ^ byte) * 0x01000193) & 0xffffffff;
    }

    final cacheDirectory = Directory(
      '$appData${Platform.pathSeparator}TrackNest${Platform.pathSeparator}'
      'playback-cache',
    );
    await cacheDirectory.create(recursive: true);
    final cacheKey =
        '${pathHash.toRadixString(16)}_${sourceStat.size}_'
        '${sourceStat.modified.millisecondsSinceEpoch}';
    final audioFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}$cacheKey.mp3',
    );
    if (await audioFile.exists() && await audioFile.length() > 0) {
      return audioFile.path;
    }

    final temporaryAudioFile = File('${audioFile.path}.partial.mp3');
    if (await temporaryAudioFile.exists()) {
      await temporaryAudioFile.delete();
    }
    final result = await Process.run(ffmpeg.path, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-nostdin',
      '-y',
      '-i',
      sourcePath,
      '-map',
      '0:a:0',
      '-vn',
      '-c:a',
      'libmp3lame',
      '-q:a',
      '3',
      '-f',
      'mp3',
      temporaryAudioFile.path,
    ], runInShell: false);
    if (result.exitCode != 0 ||
        !await temporaryAudioFile.exists() ||
        await temporaryAudioFile.length() == 0) {
      if (await temporaryAudioFile.exists()) {
        await temporaryAudioFile.delete();
      }
      final details = result.stderr.toString().toLowerCase();
      final message =
          details.contains('matches no streams') ||
              details.contains('does not contain any stream')
          ? 'This video does not contain an audio track.'
          : 'TrackNest could not read the audio track in this video.';
      throw _PlaybackPreparationException(message);
    }

    await temporaryAudioFile.rename(audioFile.path);
    return audioFile.path;
  }

  Future<void> _addSongs() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final selected = await _channel.invokeListMethod<String>(
        'selectMusicFiles',
      );
      if (!mounted || selected == null || selected.isEmpty) return;
      final existing = _songs.map((path) => path.toLowerCase()).toSet();
      var added = 0;
      for (final path in selected) {
        if (existing.add(path.toLowerCase())) {
          _songs.add(path);
          added++;
        }
      }
      await _saveLibrary();
      if (!mounted) return;
      setState(() {
        _message = added == 0
            ? 'Those songs are already in your library.'
            : 'Added $added ${added == 1 ? 'song' : 'songs'} to your library.';
        _messageIsError = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message ?? 'Could not add songs from this PC.';
        _messageIsError = true;
      });
    } on FileSystemException {
      if (!mounted) return;
      setState(() {
        _message = 'Could not save your music library on this PC.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _publishPlayback();
      }
    }
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    final path = _songs[index];
    if (!await File(path).exists()) {
      if (!mounted) return;
      setState(() {
        _message = 'This song can’t be found. It may have been moved.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _working = true;
      _currentIndex = index;
      _position = Duration.zero;
      _duration = null;
      _message = null;
    });
    _publishPlayback();
    try {
      final playbackPath = await _resolvePlaybackPath(path);
      await _player.play(DeviceFileSource(playbackPath));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is _PlaybackPreparationException
            ? error.message
            : 'TrackNest could not play this song. Try another file format.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _publishPlayback();
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_currentIndex == null) {
      if (_songs.isNotEmpty) await _playSong(0);
      return;
    }
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      _publishPlayback();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'TrackNest could not change playback.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _player.seek(position);
    if (!mounted) return;
    setState(() => _position = position);
    _publishPlayback();
  }

  Future<void> _setVolume(double volume) async {
    final selectedVolume = volume.clamp(0.0, 1.0).toDouble();
    await _player.setVolume(selectedVolume);
    if (!mounted) return;
    setState(() => _volume = selectedVolume);
    _publishPlayback();
  }

  int? _nextIndex() {
    if (_songs.isEmpty) return null;
    if (_currentIndex == null) return 0;
    if (_shuffle && _songs.length > 1) {
      final options = List<int>.generate(_songs.length, (index) => index)
        ..remove(_currentIndex);
      return options[_random.nextInt(options.length)];
    }
    if (_currentIndex! + 1 < _songs.length) return _currentIndex! + 1;
    return _repeatAll ? 0 : null;
  }

  Future<void> _advanceAfterCompletion() async {
    final index = _repeatAll && !_shuffle && _currentIndex == _songs.length - 1
        ? 0
        : _nextIndex();
    if (index == null) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = _duration ?? Duration.zero;
        });
        _publishPlayback();
      }
      return;
    }
    await _playSong(index);
  }

  Future<void> _skipNext() async {
    final index = _nextIndex();
    if (index != null) await _playSong(index);
  }

  Future<void> _skipPrevious() async {
    if (_currentIndex == null || _songs.isEmpty) return;
    if (_position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    final index = _currentIndex! > 0
        ? _currentIndex! - 1
        : (_repeatAll ? _songs.length - 1 : 0);
    await _playSong(index);
  }

  Future<void> _removeSong(int index) async {
    if (index == _currentIndex) {
      await _player.stop();
      _currentIndex = null;
      _position = Duration.zero;
      _duration = null;
      _playing = false;
    } else if (_currentIndex != null && index < _currentIndex!) {
      _currentIndex = _currentIndex! - 1;
    }
    setState(() {
      _songs.removeAt(index);
      _message = null;
    });
    _publishPlayback();
    try {
      await _saveLibrary();
    } on FileSystemException {
      if (!mounted) return;
      setState(() {
        _message = 'Could not save changes to your music library.';
        _messageIsError = true;
      });
    }
  }

  String _titleFor(String path) {
    final filename = path.split(RegExp(r'[\\/]')).last;
    final extension = filename.lastIndexOf('.');
    return extension > 0 ? filename.substring(0, extension) : filename;
  }

  String _folderFor(String path) {
    final normalized = path.replaceAll('/', '\\');
    final separator = normalized.lastIndexOf('\\');
    return separator > 0 ? normalized.substring(0, separator) : 'This PC';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final visibleSongs = _songs.where((path) {
      return query.isEmpty || _titleFor(path).toLowerCase().contains(query);
    }).toList();
    final currentSong = _currentIndex == null ? null : _songs[_currentIndex!];
    final listHeight = (visibleSongs.length * 68.0).clamp(68.0, 340.0);

    return GlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      radius: 20,
      tint: const Color(0xFF83AFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .14),
                  ),
                ),
                child: Icon(Icons.headphones_rounded, color: colors.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your music',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Listen to songs saved on this PC',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: _shuffle ? 'Turn shuffle off' : 'Shuffle songs',
                onPressed: _toggleShuffle,
                color: _shuffle ? colors.primary : null,
                icon: const Icon(Icons.shuffle_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _working || _loading ? null : _addSongs,
                icon: const Icon(Icons.library_add_outlined),
                label: const Text('Add songs'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentSong != null) ...[
            GlassSurface(
              radius: 17,
              tint: const Color(0xFF45CDB8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.primary, colors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleFor(currentSong),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Now playing · ${_folderFor(currentSong)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _shuffle ? 'Turn shuffle off' : 'Shuffle songs',
                    onPressed: () => setState(() => _shuffle = !_shuffle),
                    color: _shuffle ? colors.primary : null,
                    icon: const Icon(Icons.shuffle_rounded),
                  ),
                  IconButton(
                    tooltip: _repeatAll
                        ? 'Turn repeat off'
                        : 'Repeat the queue',
                    onPressed: () => setState(() => _repeatAll = !_repeatAll),
                    color: _repeatAll ? colors.primary : null,
                    icon: const Icon(Icons.repeat_rounded),
                  ),
                  IconButton(
                    tooltip: 'Remove from library',
                    onPressed: _working
                        ? null
                        : () => _removeSong(_currentIndex!),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else if (_songs.isEmpty && !_loading) ...[
            GlassSurface(
              width: double.infinity,
              radius: 17,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_music_outlined, color: colors.secondary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add songs from your device to start listening in TrackNest.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_loading)
            const LinearProgressIndicator()
          else if (_songs.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Library',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_songs.length} ${_songs.length == 1 ? 'song' : 'songs'}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 9),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search songs on this PC',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            if (visibleSongs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No songs match that search.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: listHeight.toDouble(),
                child: ListView.separated(
                  itemCount: visibleSongs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, visibleIndex) {
                    final song = visibleSongs[visibleIndex];
                    final index = _songs.indexOf(song);
                    final selected = index == _currentIndex;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: colors.primary.withValues(alpha: .09),
                      leading: Icon(
                        selected && _playing
                            ? Icons.graphic_eq_rounded
                            : Icons.music_note_rounded,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(
                        _titleFor(song),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _folderFor(song),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _working ? null : () => _playSong(index),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 19,
                            ),
                            label: const Text('Play'),
                          ),
                          IconButton(
                            tooltip: 'Remove from library',
                            onPressed: _working
                                ? null
                                : () => _removeSong(index),
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                        ],
                      ),
                      onTap: _working ? null : () => _playSong(index),
                    );
                  },
                ),
              ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(
                color: _messageIsError ? colors.error : colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
