# TrackNest

TrackNest is a Windows music player and media toolbox by Kryozen. It plays songs stored on your PC and includes tools for downloading supported media links and converting local files.

## What it does

- Play local MP3, WAV, M4A, AAC, WMA, and FLAC files.
- Search your local music library and control playback with play/pause, previous/next, seeking, volume, shuffle, and repeat.
- Download supported video or audio links as MP3 or MP4, choose MP3 bitrate and video quality, optionally compress MP4 output, and pick a save folder.
- Convert audio or video files already on your PC to MP3.
- Use dark or light mode and adjust motion preferences in Settings.
- View About the maker and Donations sections in the app.

## Run the Windows app

Run the app in debug mode from PowerShell:

```powershell
.\tool\run_windows.ps1
```

Build a Windows release and portable ZIP bundle:

```powershell
.\tool\prepare_media_tools.ps1
.\tool\build_windows.ps1
```

The release executable is written to `build/windows/x64/runner/Release/tracknest.exe`. The portable package is written under `dist/` and includes the Windows media tools required by the downloader.

Windows builds need Flutter, Visual Studio Build Tools with the C++ workload, and the Windows SDK. The downloader uses bundled yt-dlp, Deno, and FFmpeg; their notices are included in the portable package.

## Website

The responsive landing page is in `website/`. Preview it locally from PowerShell:

```powershell
cd website
python -m http.server 4173 --bind 127.0.0.1
```

Open `http://127.0.0.1:4173`. This address is a local preview for this PC; the deployed website is hosted separately.

## Email sign-in configuration

The Windows app reads client settings from `supabase.keys.json`; the website reads them from `website/auth-config.js`. Start from `supabase.keys.example.json`. These files use a Supabase project URL and public publishable/anon key. Do not put a service-role key in either client configuration. The actual local key file is excluded from Git.
