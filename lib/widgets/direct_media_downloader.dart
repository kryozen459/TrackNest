import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';

class DirectMediaDownloader extends StatefulWidget {
  const DirectMediaDownloader({super.key, this.initialUrl, this.requestId = 0});

  final String? initialUrl;
  final int requestId;

  @override
  State<DirectMediaDownloader> createState() => _DirectMediaDownloaderState();
}

class _DirectMediaDownloaderState extends State<DirectMediaDownloader> {
  static const MethodChannel _channel = MethodChannel(
    'tracknest/audio_converter',
  );

  final TextEditingController _urlController = TextEditingController();
  String _format = 'mp3';
  int _bitrateKbps = 192;
  int _maxVideoHeight = 0;
  bool _compressVideo = false;
  bool _working = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl ?? '';
  }

  @override
  void didUpdateWidget(covariant DirectMediaDownloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestId != oldWidget.requestId && widget.initialUrl != null) {
      _urlController.value = TextEditingValue(
        text: widget.initialUrl!,
        selection: TextSelection.collapsed(offset: widget.initialUrl!.length),
      );
      _message =
          'Playlist link ready. Choose a format, then start the download.';
      _messageIsError = false;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final rawUrl = _urlController.text.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      setState(() {
        _message = 'Enter a valid HTTPS video or audio link.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _working = true;
      _message = 'Choose a save folder. TrackNest is preparing the download…';
      _messageIsError = false;
    });

    try {
      final response = await _channel.invokeMethod<Object?>(
        'downloadMediaLink',
        {
          'url': rawUrl,
          'format': _format,
          'bitrateKbps': _bitrateKbps,
          'maxVideoHeight': _maxVideoHeight,
          'compressVideo': _format == 'mp4' && _compressVideo,
        },
      );
      if (!mounted) return;
      if (response == null) {
        setState(() => _message = null);
        return;
      }
      if (response is! Map) {
        setState(() {
          _message = 'TrackNest received an unexpected download response.';
          _messageIsError = true;
        });
        return;
      }
      if (response['success'] == true) {
        final outputPath =
            response['outputPath']?.toString() ?? 'your chosen location';
        setState(() {
          final summary =
              response['message']?.toString() ?? 'Download complete.';
          _message = '$summary Saved in $outputPath';
          _messageIsError = false;
        });
      } else {
        setState(() {
          _message =
              response['error']?.toString() ??
              'The media could not be downloaded or converted.';
          _messageIsError = true;
        });
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message ?? 'The media could not be downloaded.';
        _messageIsError = true;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _message = 'Link downloads are available in the Windows app.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      radius: 20,
      tint: const Color(0xFF42CBB7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Download media from a link',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a supported video or audio link. Choose MP3 or MP4 settings and a save folder before starting.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _urlController,
            enabled: !_working,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 8192,
            decoration: const InputDecoration(
              labelText: 'Video or audio link',
              hintText: 'Paste a supported media URL',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
              filled: true,
              counterText: '',
            ),
            onSubmitted: (_) {
              if (!_working) _download();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _format,
                onChanged: _working
                    ? null
                    : (value) {
                        if (value != null) setState(() => _format = value);
                      },
                items: const [
                  DropdownMenuItem(value: 'mp3', child: Text('Save as MP3')),
                  DropdownMenuItem(value: 'mp4', child: Text('Save as MP4')),
                ],
              ),
              if (_format == 'mp3')
                DropdownButton<int>(
                  value: _bitrateKbps,
                  onChanged: _working
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _bitrateKbps = value);
                          }
                        },
                  items: const [128, 192, 256, 320]
                      .map(
                        (bitrate) => DropdownMenuItem<int>(
                          value: bitrate,
                          child: Text('$bitrate kbps'),
                        ),
                      )
                      .toList(),
                ),
              if (_format == 'mp4')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Quality'),
                    const SizedBox(width: 6),
                    DropdownButton<int>(
                      value: _maxVideoHeight,
                      onChanged: _working
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _maxVideoHeight = value);
                              }
                            },
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text('Best available'),
                        ),
                        DropdownMenuItem(
                          value: 2160,
                          child: Text('Up to 2160p'),
                        ),
                        DropdownMenuItem(
                          value: 1440,
                          child: Text('Up to 1440p'),
                        ),
                        DropdownMenuItem(
                          value: 1080,
                          child: Text('Up to 1080p'),
                        ),
                        DropdownMenuItem(value: 720, child: Text('Up to 720p')),
                        DropdownMenuItem(value: 480, child: Text('Up to 480p')),
                        DropdownMenuItem(value: 360, child: Text('Up to 360p')),
                      ],
                    ),
                  ],
                ),
              FilledButton.icon(
                onPressed: _working ? null : _download,
                icon: const Icon(Icons.download_outlined),
                label: Text(_working ? 'Working…' : 'Download and convert'),
              ),
            ],
          ),
          if (_format == 'mp4')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: const Icon(Icons.compress_outlined),
              title: const Text('Compress video'),
              subtitle: const Text(
                'Try to make the file smaller. Takes longer; results vary.',
              ),
              value: _compressVideo,
              onChanged: _working
                  ? null
                  : (value) => setState(() => _compressVideo = value),
            ),
          if (_working) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            SelectableText(
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
