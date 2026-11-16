# Metadata source review

This review limits playlist integrations to official, documented metadata APIs. TrackNest does not download or extract audio from playlist services. Windows also provides a separate local-file converter for audio files the user selects from the device.

| Source | Official metadata path | Access constraints | Audio export |
| --- | --- | --- | --- |
| Spotify | Web API GET /playlists/{id} and playlist items | OAuth 2.0. Playlist items are currently available only for playlists the authorizing user owns or collaborates on. Spotify requires attribution and links back to Spotify content. | Disabled. Spotify explicitly prohibits app-facilitated content downloads and stream ripping. |
| YouTube | YouTube Data API playlists.list and playlistItems.list | Public resources need an API key; user data may need OAuth. API use has quota and policy requirements. Non-authorized API data must be refreshed or deleted within 30 days. YouTube branding and terms links are required. | Disabled. YouTube policy prohibits downloading, importing, backing up, caching, or storing audiovisual content without prior written approval. |
| SoundCloud | SoundCloud Public API playlist and resolve endpoints | An app must be registered. Current registration requires an Artist Pro subscription. Public resources use OAuth client credentials; user resources use OAuth 2.1. Keep the client secret off client devices. | Disabled. Current API terms prohibit offline access to User Content, including audio downloads, even when an uploader has enabled downloads on SoundCloud. |

## Implementation decision

1. Keep saved source links separate from imported metadata.
2. Implement provider adapters behind PlaylistMetadataProvider.
3. Preserve source links and attribution for every metadata result.
4. Add source-specific consent, privacy disclosures, refresh/expiry handling, and credential configuration before enabling any provider.
5. Keep audio export disabled wherever the source terms prohibit offline copies, even when a creator-facing download switch or endpoint exists.

This is a development review, not a substitute for reviewing the current source terms before a public release.

## YouTube adapter status

The first metadata adapter is implemented in lib/data/youtube/youtube_playlist_metadata_provider.dart. It accepts public YouTube playlist URLs, reads playlist details and paginated playlist items through the official Data API, and returns a metadata snapshot in memory. It does not download audio or persist API-returned metadata.

The adapter is connected to the library UI for public playlists. Before each import, the app presents its privacy notice, terms, YouTube Terms of Service, and a required agreement checkbox. The metadata page uses an official YouTube brand asset linked to the source playlist. Returned API data is not persisted; the result screen closes after 29 days. Live requests require a restricted API key supplied at build or run time. For web builds, restrict the key to YouTube Data API v3 and the app origin.

For YouTube Data API usage, the app requires explicit agreement before a request, links to YouTube Terms of Service and Google Privacy Policy, displays the official YouTube attribution asset next to API results, and expires returned metadata after 29 days. Imported metadata remains in memory and is not persisted.

## Windows local audio conversion

The Windows desktop app can batch-convert audio files selected from the local device to MP3 using Media Foundation. The user chooses an output folder and a bitrate (128, 192, 256, or 320 kbps). This path only reads the selected local files; it does not use playlist URLs or contact media services.

## Current coverage

The YouTube Data API adapter is implemented, but the Windows release keeps it disabled until the app can use a secure backend. Spotify and SoundCloud playlist URLs can be saved and opened, but their metadata providers and account authorization flows are not implemented. SoundCloud API registration currently requires Artist Pro, and current API terms prohibit offline copies of SoundCloud content; the presence of a track download flag does not override that restriction. Spotify and YouTube audio export remain disabled under their platform policies.

## Official references

- [Spotify Get Playlist](https://developer.spotify.com/documentation/web-api/reference/get-playlist) and [February 2026 migration guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)
- [YouTube playlists.list](https://developers.google.com/youtube/v3/docs/playlists/list), [playlistItems.list](https://developers.google.com/youtube/v3/docs/playlistItems/list), and [Developer Policies](https://developers.google.com/youtube/terms/developer-policies)
- [SoundCloud API guide](https://developers.soundcloud.com/docs/api/), [API Terms of Use](https://developers.soundcloud.com/docs/api/terms-of-use), and [API registration requirements](https://developers.soundcloud.com/docs/api/register-app)

