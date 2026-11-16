$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$executable = Join-Path $projectRoot 'build\windows\x64\runner\Debug\tracknest.exe'

if (-not (Test-Path -LiteralPath $executable)) {
  $releaseExecutable = Join-Path $projectRoot 'build\windows\x64\runner\Release\tracknest.exe'
  if (Test-Path -LiteralPath $releaseExecutable) {
    $executable = $releaseExecutable
  } else {
    throw 'No Windows build exists yet. Run tool\build_windows.ps1 first.'
  }
}

$appDirectory = Split-Path -Parent $executable
Start-Process -FilePath $executable -WorkingDirectory $appDirectory
