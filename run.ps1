param([string]$Device = 'chrome')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { Join-Path $env:USERPROFILE 'develop\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Установите Flutter SDK и добавьте flutter/bin в PATH.' }
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $flutterPath run -d $Device
