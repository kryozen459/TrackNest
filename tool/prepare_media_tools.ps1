$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsDirectory = Join-Path $projectRoot 'windows\runner\media-tools'
$cacheDirectory = Join-Path $PSScriptRoot '.media-tool-cache'
$downloadDirectory = Join-Path $cacheDirectory 'downloads'
$extractDirectory = Join-Path $cacheDirectory 'extract'
New-Item -ItemType Directory -Path $toolsDirectory, $downloadDirectory, $extractDirectory -Force | Out-Null

function Get-VerifiedDownload([string]$Url, [string]$Path, [string]$ExpectedSha256) {
  if (-not (Test-Path -LiteralPath $Path)) {
    Invoke-WebRequest -Uri $Url -OutFile $Path
  }
  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
    Remove-Item -LiteralPath $Path -Force
    throw "Checksum verification failed for $([IO.Path]::GetFileName($Path))."
  }
}

$ytDlpPath = Join-Path $toolsDirectory 'yt-dlp.exe'
$ytDlpDownload = Join-Path $downloadDirectory 'yt-dlp-2026.10.26.exe'
Get-VerifiedDownload 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.26/yt-dlp.exe' $ytDlpDownload 'f5389d3698ecde4ef06f4e6b1ce0294fe9ac1396228c8990b8d3416d6d177a7d'
Copy-Item -LiteralPath $ytDlpDownload -Destination $ytDlpPath -Force

$denoZip = Join-Path $downloadDirectory 'deno-v2.9.8-win-x64.zip'
Get-VerifiedDownload 'https://github.com/denoland/deno/releases/download/v2.9.8/deno-x86_64-pc-windows-msvc.zip' $denoZip 'cba84b26e0df5ae7f74fc66b86a95b866872a86292ebd84fa1e959927edd93bf'
$denoExtract = Join-Path $extractDirectory 'deno'
if (Test-Path -LiteralPath $denoExtract) {
  Remove-Item -LiteralPath $denoExtract -Recurse -Force
}
New-Item -ItemType Directory -Path $denoExtract -Force | Out-Null
Expand-Archive -LiteralPath $denoZip -DestinationPath $denoExtract -Force
$denoExecutable = Get-ChildItem -LiteralPath $denoExtract -Filter 'deno.exe' -Recurse | Select-Object -First 1
if (-not $denoExecutable) { throw 'The Deno package did not contain deno.exe.' }
Copy-Item -LiteralPath $denoExecutable.FullName -Destination (Join-Path $toolsDirectory 'deno.exe') -Force

$ffmpegZip = Join-Path $downloadDirectory 'ffmpeg-N-128900-gf8bb61cd57-win64-gpl-shared.zip'
Get-VerifiedDownload 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2026-11-13-21-03/ffmpeg-N-128900-gf8bb61cd57-win64-gpl-shared.zip' $ffmpegZip '403f726d46f9b663d0c051bd8c9e9ceb83461517848fbcb925646fdedf190b11'
$ffmpegExtract = Join-Path $extractDirectory 'ffmpeg'
if (Test-Path -LiteralPath $ffmpegExtract) {
  Remove-Item -LiteralPath $ffmpegExtract -Recurse -Force
}
New-Item -ItemType Directory -Path $ffmpegExtract -Force | Out-Null
Expand-Archive -LiteralPath $ffmpegZip -DestinationPath $ffmpegExtract -Force
$ffmpegBin = Get-ChildItem -LiteralPath $ffmpegExtract -Directory -Filter 'bin' -Recurse | Select-Object -First 1
if (-not $ffmpegBin -or
    -not (Test-Path -LiteralPath (Join-Path $ffmpegBin.FullName 'ffmpeg.exe')) -or
    -not (Test-Path -LiteralPath (Join-Path $ffmpegBin.FullName 'ffprobe.exe'))) {
  throw 'The FFmpeg package did not contain its media executables.'
}
foreach ($fileName in @('ffmpeg.exe', 'ffprobe.exe', 'ffplay.exe')) {
  $oldFile = Join-Path $toolsDirectory $fileName
  if (Test-Path -LiteralPath $oldFile) { Remove-Item -LiteralPath $oldFile -Force }
}
Get-ChildItem -Path (Join-Path $toolsDirectory '*.dll') -File -ErrorAction SilentlyContinue |
  Remove-Item -Force
Copy-Item -LiteralPath (Join-Path $ffmpegBin.FullName 'ffmpeg.exe') -Destination $toolsDirectory -Force
Copy-Item -LiteralPath (Join-Path $ffmpegBin.FullName 'ffprobe.exe') -Destination $toolsDirectory -Force
Copy-Item -Path (Join-Path $ffmpegBin.FullName '*.dll') -Destination $toolsDirectory -Force
$releaseToolsDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release\media-tools'
$oldReleasePlayer = Join-Path $releaseToolsDirectory 'ffplay.exe'
if (Test-Path -LiteralPath $oldReleasePlayer) {
  Remove-Item -LiteralPath $oldReleasePlayer -Force
}$licenses = Join-Path $toolsDirectory 'licenses'
New-Item -ItemType Directory -Path $licenses -Force | Out-Null
Invoke-WebRequest 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.10.26/LICENSE' -OutFile (Join-Path $licenses 'yt-dlp-LICENSE.txt')
Invoke-WebRequest 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.10.26/THIRD_PARTY_LICENSES.txt' -OutFile (Join-Path $licenses 'yt-dlp-THIRD_PARTY_LICENSES.txt')
Invoke-WebRequest 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/LICENSE.md' -OutFile (Join-Path $licenses 'deno-LICENSE.md')
Invoke-WebRequest 'https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/COPYING.GPLv3' -OutFile (Join-Path $licenses 'ffmpeg-COPYING.GPLv3.txt')

$noticeLines = @(
  'TrackNest Windows media tools',
  '',
  'yt-dlp 2026.10.26',
  'Source: https://github.com/yt-dlp/yt-dlp',
  'License files: licenses\yt-dlp-LICENSE.txt and licenses\yt-dlp-THIRD_PARTY_LICENSES.txt',
  '',
  'Deno 2.9.8',
  'Source: https://github.com/denoland/deno',
  'License file: licenses\deno-LICENSE.md',
  '',
  'FFmpeg N-128900-gf8bb61cd57 (Windows x64 GPL shared build)',
  'Source: https://github.com/yt-dlp/FFmpeg-Builds',
  'Corresponding source: https://github.com/FFmpeg/FFmpeg',
  'License file: licenses\ffmpeg-COPYING.GPLv3.txt'
)
$notice = $noticeLines -join [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $toolsDirectory 'THIRD_PARTY_NOTICES.txt'), $notice, [Text.UTF8Encoding]::new($false))

$ytVersion = & $ytDlpPath --version
$denoVersion = & (Join-Path $toolsDirectory 'deno.exe') --version | Select-Object -First 1
$ffmpegVersion = & (Join-Path $toolsDirectory 'ffmpeg.exe') -version | Select-Object -First 1
Write-Output "Prepared $ytVersion, $denoVersion, and $ffmpegVersion."