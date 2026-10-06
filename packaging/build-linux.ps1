#requires -Version 7
<#
.SYNOPSIS
  Builds the acme-manager Linux package (.tar.gz).

.DESCRIPTION
  Publishes the Service as a self-contained linux-x64 build (no .NET runtime
  required on the target host), stages it with the systemd unit and install/
  uninstall scripts, normalises the shell scripts to LF line endings, and packs
  a tarball that installs on any systemd distro (Ubuntu, RHEL/Rocky/Alma, ...).

  Output: artifacts/acme-manager-linux-x64-<version>.tar.gz

.PARAMETER Version
  Version stamped into the package name. Defaults to the project's VersionPrefix
  (from Directory.Build.props), so a bare invocation uses the real version.

.PARAMETER Runtime
  .NET runtime identifier to publish (default linux-x64; linux-arm64 also works).

.EXAMPLE
  pwsh packaging/build-linux.ps1 -Version 0.5.0
#>
[CmdletBinding()]
param(
    [string] $Version = "",
    [string] $Runtime = "linux-x64",
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot "..")
$svcProj    = Join-Path $repoRoot "core/src/AcmeManager.Service/AcmeManager.Service.csproj"

# Default the version to the project's VersionPrefix (honours Directory.Build.props)
# so a bare invocation uses the real product version. Pass -Version to override.
# Must resolve before the staged/tarball paths below, which interpolate $Version.
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (dotnet msbuild $svcProj -getProperty:VersionPrefix -nologo).Trim()
    if ([string]::IsNullOrWhiteSpace($Version)) { throw "Could not resolve the project version; pass -Version explicitly." }
    Write-Host "==> Version not specified; using project VersionPrefix $Version" -ForegroundColor DarkGray
}
$linuxFiles = $PSScriptRoot | Join-Path -ChildPath "linux"
$publishDir = Join-Path $repoRoot "artifacts/publish/$Runtime"
$stageRoot  = Join-Path $repoRoot "artifacts/stage/acme-manager-$Runtime-$Version"
$artifacts  = Join-Path $repoRoot "artifacts"
$tarball    = Join-Path $artifacts "acme-manager-$Runtime-$Version.tar.gz"

Write-Host "==> Publishing self-contained $Runtime build..." -ForegroundColor Cyan
if (Test-Path $publishDir) { Remove-Item -Recurse -Force $publishDir }
dotnet publish $svcProj `
    -c $Configuration -r $Runtime --self-contained true `
    -p:PublishSingleFile=false `
    -o $publishDir
if ($LASTEXITCODE) { throw "dotnet publish failed ($LASTEXITCODE)" }

Write-Host "==> Staging package (v$Version)..." -ForegroundColor Cyan
if (Test-Path $stageRoot) { Remove-Item -Recurse -Force $stageRoot }
New-Item -ItemType Directory -Force -Path (Join-Path $stageRoot "app") | Out-Null
Copy-Item -Recurse -Force (Join-Path $publishDir "*") (Join-Path $stageRoot "app")

# Scripts + unit + readme live at the package root, next to the app/ folder.
foreach ($f in @("acme-manager.service", "install.sh", "uninstall.sh", "README.md")) {
    Copy-Item -Force (Join-Path $linuxFiles $f) (Join-Path $stageRoot $f)
}

# Shell scripts MUST be LF — a CRLF shebang ("#!/bin/bash\r") breaks with
# "bad interpreter"; a CRLF systemd unit leaves a trailing \r on ExecStart/
# Environment values. Normalise regardless of how git stored them.
foreach ($unix in @("install.sh", "uninstall.sh", "acme-manager.service")) {
    $p = Join-Path $stageRoot $unix
    $text = [IO.File]::ReadAllText($p) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($p, $text, [Text.UTF8Encoding]::new($false))
}

Write-Host "==> Packing tarball..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
if (Test-Path $tarball) { Remove-Item -Force $tarball }
# bsdtar (bundled with Windows 10+) preserves the executable bit on *.sh.
tar -czf $tarball -C (Split-Path $stageRoot -Parent) (Split-Path $stageRoot -Leaf)
if ($LASTEXITCODE) { throw "tar failed ($LASTEXITCODE)" }

Write-Host ""
Write-Host "Linux package built: $tarball" -ForegroundColor Green
Write-Host ("Size: {0:N1} MB" -f ((Get-Item $tarball).Length / 1MB))
Write-Host "Install on the host: tar -xzf <file>.tar.gz && cd acme-manager-$Runtime-$Version && sudo bash install.sh"
