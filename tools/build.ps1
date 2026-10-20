<#
.SYNOPSIS
  Build the Robbo Game Boy port.

.DESCRIPTION
  Compiles every .c file under gb/src into its own object file, then links the
  objects with GBDK's lcc.  Compiling separately keeps per-file #pragma bank
  directives intact and makes incremental builds possible.

.PARAMETER DebugRom
  Build the DEBUG_STATE ROM (roms/robbo-debug.gb).

.PARAMETER Clean
  Delete the build directory before compiling.

.PARAMETER Smoke
  Build the Phase-0 bank-switching smoke ROM instead of the game.

.EXAMPLE
  ./gb/tools/build.ps1
  ./gb/tools/build.ps1 -DebugRom
#>
[CmdletBinding()]
param(
    [switch]$DebugRom,
    [switch]$Clean,
    [switch]$Smoke
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gbdk     = Join-Path $repoRoot 'gbdk'
$lcc      = Join-Path $gbdk 'bin\lcc.exe'
$srcRoot  = Join-Path $repoRoot 'gb\src'
$build    = Join-Path $repoRoot 'gb\build'
$objDir   = Join-Path $build 'obj'
$romDir   = Join-Path $repoRoot 'roms'

if (-not (Test-Path $lcc)) {
    throw "GBDK lcc not found at $lcc"
}

if ($Clean -and (Test-Path $build)) {
    Remove-Item -Recurse -Force $build
}
New-Item -ItemType Directory -Force -Path $objDir, $romDir | Out-Null

$defines = @()
$romName = 'robbo'
$sourceRoot = $srcRoot

if ($Smoke) {
    $sourceRoot = Join-Path $repoRoot 'gb\tests\smoke\banksmoke'
    $romName = 'bank-smoke'
    $defines += '-DBANK_SMOKE'
}
if ($DebugRom) {
    if ($Smoke) { throw '-Smoke and -DebugRom are mutually exclusive' }
    $romName = 'robbo-debug'
    $defines += '-DDEBUG_STATE'
}

$sources = Get-ChildItem -Path $sourceRoot -Recurse -Filter '*.c' | Sort-Object FullName
if (-not $sources) {
    throw "No C sources found under $sourceRoot"
}

# GBDK defaults plus the project's chosen cartridge configuration.
$commonFlags = @(
    '-Wm-ynROBBO'
    '-Wl-yt0x19'   # MBC5
    '-Wl-yo8'      # 8 x 16 KiB banks (levels live in banks 1..7)
    '-Wl-j'        # emit .noi debug info
    '-Wl-w'        # show linker warnings
    '-Wf--opt-code-speed'
)

$objects = @()
$failed = $false

foreach ($src in $sources) {
    $rel = [System.IO.Path]::GetRelativePath($sourceRoot, $src.FullName)
    $safe = ($rel -replace '[\\/]', '_') -replace '\.c$', ''
    $obj = Join-Path $objDir "$safe.o"

    $needsBuild = $true
    if ((Test-Path $obj) -and ((Get-Item $obj).LastWriteTime -ge $src.LastWriteTime)) {
        $needsBuild = $false
    }

    if ($needsBuild) {
        Write-Host "CC  $rel"
        & $lcc -c @defines @commonFlags -o $obj $src.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Compilation failed: $rel"
            $failed = $true
            continue
        }
    }
    $objects += $obj
}

if ($failed) { throw 'Build failed' }

$out = Join-Path $romDir "$romName.gb"
Write-Host "LD  $out"
& $lcc @defines @commonFlags -Wl-m -o $out @objects
if ($LASTEXITCODE -ne 0) { throw 'Link failed' }

# lcc writes the map file next to the output ROM; keep a stable copy.
$map = Join-Path $romDir "$romName.map"
if (Test-Path $map) {
    Write-Host "MAP $map"
}

Write-Host "OK  $out"
