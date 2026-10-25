<#
.SYNOPSIS
  Build the Robbo Game Boy port.

.DESCRIPTION
  Compiles every .c file under gb/src into its own object file, then links the
  objects with GBDK's lcc.  Compiling separately keeps per-file #pragma bank
  directives intact and makes incremental builds possible.

  By default two ROMs are produced:
    roms/robbo.gb        release build (Select level-warp debug hook disabled)
    roms/robbo-debug.gb  debug build (-DDEBUG_STATE: Select level-warp hooks)

  Each variant has its own object directory, so a stale DEBUG_STATE object can
  never leak into the release ROM.

.PARAMETER DebugRom
  Build only the debug ROM (roms/robbo-debug.gb).

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
$romDir   = Join-Path $repoRoot 'roms'

if (-not (Test-Path $lcc)) {
    throw "GBDK lcc not found at $lcc"
}

if ($Clean -and (Test-Path $build)) {
    Remove-Item -Recurse -Force $build
}
New-Item -ItemType Directory -Force -Path $romDir | Out-Null

# GBDK defaults plus the project's chosen cartridge configuration.
$commonFlags = @(
    '-Wm-ynROBBO'
    '-Wm-yc'       # GameBoy Color compatible: colour on CGB, DMG build unchanged
    '-Wl-yt0x1B'   # MBC5 + cartridge RAM (MidnightTrace FRAM; battery bit is metadata only)
    '-Wl-yo16'     # 16 x 16 KiB ROM banks
    '-Wl-ya16'     # 16 x 8 KiB RAM banks = 128 KiB FRAM, header 0x149 = 0x04
    '-Wl-j'        # emit .noi debug info
    '-Wl-w'        # show linker warnings
    '-Wf--opt-code-speed'
)

function Invoke-Variant {
    param(
        [string]$Name,
        [string]$RomName,
        [string]$SourceRoot,
        [string[]]$Defines
    )

    $objDir = Join-Path $build "obj\$Name"
    New-Item -ItemType Directory -Force -Path $objDir | Out-Null

    # Timestamp-incremental objects are safe inside a variant, but a changed
    # define list must force a full recompile of that variant.
    $defineKey = $Defines -join ' '
    $stamp = Join-Path $objDir 'defines.txt'
    $stampText = ''
    if (Test-Path $stamp) {
        $stampText = (Get-Content -Raw -Path $stamp)
        if ($null -eq $stampText) { $stampText = '' }
        $stampText = $stampText.Trim()
    }
    if ($stampText -ne $defineKey) {
        Get-ChildItem -Path $objDir -Filter '*.o' -File |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Set-Content -Path $stamp -Value $defineKey
    }

    $sources = Get-ChildItem -Path $SourceRoot -Recurse -Filter '*.c' | Sort-Object FullName
    if (-not $sources) {
        throw "No C sources found under $SourceRoot"
    }

    $objects = @()
    $failed = $false

    foreach ($src in $sources) {
        $rel = [System.IO.Path]::GetRelativePath($SourceRoot, $src.FullName)
        $safe = ($rel -replace '[\\/]', '_') -replace '\.c$', ''
        $obj = Join-Path $objDir "$safe.o"

        $needsBuild = $true
        if ((Test-Path $obj) -and ((Get-Item $obj).LastWriteTime -ge $src.LastWriteTime)) {
            $needsBuild = $false
        }

        if ($needsBuild) {
            Write-Host "CC  [$Name] $rel"
            & $lcc -c @Defines @commonFlags -o $obj $src.FullName
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Compilation failed: $rel ($Name)"
                $failed = $true
                continue
            }
        }
        $objects += $obj
    }

    if ($failed) { throw "Build failed: $Name" }

    $out = Join-Path $romDir "$RomName.gb"
    Write-Host "LD  [$Name] $out"
    & $lcc @Defines @commonFlags -Wl-m -o $out @objects
    if ($LASTEXITCODE -ne 0) { throw "Link failed: $Name" }

    # lcc writes the map file next to the output ROM; keep a stable copy.
    $map = Join-Path $romDir "$RomName.map"
    if (Test-Path $map) {
        Write-Host "MAP $map"
    }

    Write-Host "OK  $out"
}

if ($Smoke) {
    if ($DebugRom) { throw '-Smoke and -DebugRom are mutually exclusive' }
    Invoke-Variant -Name 'smoke' -RomName 'bank-smoke' `
        -SourceRoot (Join-Path $repoRoot 'gb\tests\smoke\banksmoke') `
        -Defines @('-DBANK_SMOKE')
} elseif ($DebugRom) {
    Invoke-Variant -Name 'debug' -RomName 'robbo-debug' `
        -SourceRoot $srcRoot -Defines @('-DDEBUG_STATE')
} else {
    Invoke-Variant -Name 'release' -RomName 'robbo' `
        -SourceRoot $srcRoot -Defines @()
    Invoke-Variant -Name 'debug' -RomName 'robbo-debug' `
        -SourceRoot $srcRoot -Defines @('-DDEBUG_STATE')
}
