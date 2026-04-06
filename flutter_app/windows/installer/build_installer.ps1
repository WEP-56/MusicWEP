param(
    [string]$MakensisPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$installerScript = Join-Path $scriptDir "MusicWEP.nsi"
$outputDir = Join-Path $scriptDir "dist"

function Resolve-MakensisPath {
    param([string]$Candidate)

    if ($Candidate) {
        if (-not (Test-Path $Candidate)) {
            throw "Specified makensis path does not exist: $Candidate"
        }
        return (Resolve-Path $Candidate).Path
    }

    $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $commonPaths = @(
        "C:\Program Files (x86)\NSIS\makensis.exe",
        "C:\Program Files\NSIS\makensis.exe",
        "D:\NSIS\makensis.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw "makensis.exe was not found. Add NSIS to PATH or pass -MakensisPath."
}

function Get-AppVersion {
    $line = Select-String -Path $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\d+)?' | Select-Object -First 1
    if (-not $line) {
        throw "Unable to read version from pubspec.yaml."
    }
    return $line.Matches[0].Groups[1].Value
}

$makensis = Resolve-MakensisPath -Candidate $MakensisPath
$appVersion = Get-AppVersion
$releaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"

Push-Location $projectRoot
try {
    flutter build windows --release
} finally {
    Pop-Location
}

if (-not (Test-Path $releaseDir)) {
    throw "Release output directory was not found: $releaseDir"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$arguments = @(
    "/DAPP_VERSION=$appVersion",
    "/DPROJECT_ROOT=$projectRoot",
    "/DRELEASE_DIR=$releaseDir",
    "/DOUTPUT_DIR=$outputDir",
    $installerScript
)

& $makensis @arguments
