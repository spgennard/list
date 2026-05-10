#!/usr/bin/env pwsh
#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

$Repo   = 'spgennard/list'
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
$BinDir = Join-Path $PSScriptRoot 'bin'

# Detect OS and architecture
$OS   = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
$Arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture

$Pattern = switch ($true) {
    ($IsWindows -and $Arch -eq 'X64')                               { 'win-x64';      break }
    ($IsMacOS   -and $Arch -eq 'Arm64')                             { 'macos-arm64';  break }
    ($IsMacOS   -and $Arch -eq 'X64')                               { 'macos-x64';    break }
    ($IsLinux   -and $Arch -eq 'X64')                               { 'linux-x64';    break }
    ($IsLinux   -and $Arch -in @('Arm64','Arm'))                    { 'linux-arm64';  break }
    default {
        Write-Error "Unsupported platform: OS='$OS' Arch='$Arch'"
        exit 1
    }
}

Write-Host "Fetching latest release info from $Repo..."
$Release  = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing
$Asset    = $Release.assets | Where-Object { $_.name -like "*$Pattern*" } | Select-Object -First 1

if (-not $Asset) {
    Write-Error "No release asset found matching platform: $Pattern"
    exit 1
}

$DownloadUrl = $Asset.browser_download_url
$Filename    = $Asset.name
$TmpDir      = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    $OutFile = Join-Path $TmpDir $Filename
    Write-Host "Downloading $Filename..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutFile -UseBasicParsing

    Write-Host "Extracting..."
    if ($Filename -like '*.zip') {
        Expand-Archive -Path $OutFile -DestinationPath $TmpDir -Force
    } else {
        # tar is available on Windows 10+, macOS, and Linux
        & tar -xzf $OutFile -C $TmpDir
    }

    # Find the extracted binary (list or list.exe on Windows)
    $BinaryName = if ($IsWindows) { 'list.exe' } else { 'list' }
    $ListBin = Get-ChildItem -Path $TmpDir -Filter $BinaryName -Recurse -File |
               Select-Object -First 1

    if (-not $ListBin) {
        Write-Error "Could not find '$BinaryName' binary in archive"
        exit 1
    }

    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir | Out-Null
    }

    $Destination = Join-Path $BinDir $BinaryName
    Copy-Item -Path $ListBin.FullName -Destination $Destination -Force

    if (-not $IsWindows) {
        chmod +x $Destination
    }

    Write-Host "Installed list -> $Destination"
}
finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
