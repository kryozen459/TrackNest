$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$keyFile = Join-Path $projectRoot 'local.keys.json'

if (-not (Test-Path -LiteralPath $keyFile)) {
  throw "Create local.keys.json from local.keys.example.json and add a restricted YouTube Data API key."
}

$config = Get-Content -LiteralPath $keyFile -Raw | ConvertFrom-Json
$key = [string]$config.YOUTUBE_DATA_API_KEY
if ([string]::IsNullOrWhiteSpace($key) -or $key -eq 'replace-with-a-restricted-key') {
  throw 'Add your restricted key to local.keys.json before running the app.'
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
  $flutterPath = $flutterCommand.Source
} else {
  $bundledSdk = Join-Path $projectRoot '..\..\..\tools\flutter\bin\flutter.bat'
  if (-not (Test-Path -LiteralPath $bundledSdk)) {
    throw 'Flutter was not found. Open a new terminal or install Flutter and add it to PATH.'
  }
  $flutterPath = (Resolve-Path -LiteralPath $bundledSdk).Path
}

& $flutterPath run -d chrome "--dart-define-from-file=$keyFile"
exit $LASTEXITCODE
