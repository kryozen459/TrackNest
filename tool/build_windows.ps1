$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'prepare_media_tools.ps1')


$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
  $flutterPath = $flutterCommand.Source
} else {
  $bundledSdk = Join-Path $projectRoot '..\..\..\tools\flutter\bin\flutter.bat'
  if (-not (Test-Path -LiteralPath $bundledSdk)) {
    throw 'Flutter was not found. Add Flutter to PATH or install it under D:\KRYOZEN\code\Codex\tools\flutter.'
  }
  $flutterPath = (Resolve-Path -LiteralPath $bundledSdk).Path
}

Push-Location $projectRoot
try {
  & $flutterPath analyze
  if ($LASTEXITCODE -ne 0) {
    throw 'Flutter analysis failed; release build stopped.'
  }

  & $flutterPath test
  if ($LASTEXITCODE -ne 0) {
    throw 'Flutter tests failed; release build stopped.'
  }

  $buildArguments = @('build', 'windows', '--release')
  $authConfig = Join-Path $projectRoot 'supabase.keys.json'
  if (Test-Path -LiteralPath $authConfig) {
    $buildArguments += "--dart-define-from-file=$authConfig"
  }
  & $flutterPath @buildArguments
  if ($LASTEXITCODE -ne 0) {
    throw 'Windows release build failed.'
  }

  $releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
  $executable = Join-Path $releaseDirectory 'tracknest.exe'
  if (-not (Test-Path -LiteralPath $executable)) {
    throw "Expected Windows executable was not produced: $executable"
  }

  $distributionDirectory = Join-Path $projectRoot 'dist'
  New-Item -ItemType Directory -Path $distributionDirectory -Force | Out-Null
  $packageDirectory = Join-Path $distributionDirectory 'TrackNest-windows-x64-trial'
  New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
  Copy-Item -Path (Join-Path $releaseDirectory '*') -Destination $packageDirectory -Recurse -Force

  $archive = Join-Path $distributionDirectory 'TrackNest-windows-x64-trial.zip'
  Compress-Archive -Path (Join-Path $packageDirectory '*') -DestinationPath $archive -Force
  Write-Host "Windows app: $executable"
  Write-Host "Windows portable app folder: $packageDirectory"
  Write-Host "Windows release ZIP: $archive"
} finally {
  Pop-Location
}
