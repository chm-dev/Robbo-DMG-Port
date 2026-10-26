<#
.SYNOPSIS
  Build the Robbo Game Boy or NES port.

.DESCRIPTION
  Compiles every .c file under gb/src into its own object file, then links the
  objects with GBDK's lcc.  Compiling separately keeps per-file #pragma bank
  directives intact and makes incremental builds possible.

  By default two Game Boy ROMs are produced:
    roms/robbo.gb        release build (Select level-warp debug hook disabled)
    roms/robbo-debug.gb  debug build (-DDEBUG_STATE: Select level-warp hooks)

  With -Target nes the same shared sources are built for the NES:
    roms/robbo.nes        release build
    roms/robbo-debug.nes  debug build (-DDEBUG_STATE)

  Each target/variant has its own object directory, so a stale object from
  another target or define set can never leak into the ROM.

.PARAMETER Target
  gb (default) or nes.

.PARAMETER DebugRom
  Build only the debug ROM.

.PARAMETER Clean
  Delete the build directory before compiling.

.PARAMETER Smoke
  Build the Phase-0 Game Boy bank-switching smoke ROM instead of the game.

.EXAMPLE
  ./gb/tools/build.ps1
  ./gb/tools/build.ps1 -Target nes
  ./gb/tools/build.ps1 -Target nes -DebugRom
#>
[CmdletBinding()]
param(
    [ValidateSet('gb', 'nes')]
    [string]$Target = 'gb',
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

if ($Smoke -and $Target -ne 'gb') {
    throw '-Smoke is only supported for -Target gb'
}

if ($Clean -and (Test-Path $build)) {
    Remove-Item -Recurse -Force $build
}
New-Item -ItemType Directory -Force -Path $romDir | Out-Null

# Target settings.  The GB flags preserve the project's MBC5 + 128 KiB FRAM
# cartridge.  GBDK-NES lcc defaults to UNROM-512 (mapper 30), which has no
# PRG-RAM; Repair-NesHeader below switches the ROM to the mapper-2 UNROM-512
# + Save RAM board instead, using a NES 2.0 header so FCEUX and MiSTer map
# the 8 KiB PRG-RAM window.  The linker puts _DATA/_BSS in its
# battery-backed PRG-RAM window at $6000-$7FFF.  bss_start/bss_size are
# C-visible aliases for the linker's s__BSS/l__BSS and are used by
# platform_ram_init() to clear PRG-RAM before main().
if ($Target -eq 'nes') {
    $portFlags = @(
        '-mmos6502:nes'
        '-Wm-yoA'                      # auto-size; current layout emits 512 KiB
        '-Wl-b_DATA=0x6000'            # gameplay RAM + BSS in PRG-RAM
        '-Wl-g_bss_start=s__BSS'
        '-Wl-g_bss_size=l__BSS'
        '-Wl-j'                        # .noi debug info
        '-Wl-w'                        # linker warnings
        '-Wl-m'                        # .map file
        '-Wf--opt-code-size'           # 16 KiB bank 0 is tighter than on GB
        '-Wf--no-zp-spill'             # keep locals out of the 224-byte NES ZP
    )
    $outExt = '.nes'
} else {
    $portFlags = @(
        '-msm83:gb'
        '-Wm-ynROBBO'
        '-Wm-yc'       # GameBoy Color compatible: colour on CGB, DMG build unchanged
        '-Wl-yt0x1B'   # MBC5 + cartridge RAM (MidnightTrace FRAM; battery bit is metadata only)
        '-Wl-yo16'     # 16 x 16 KiB ROM banks
        '-Wl-ya16'     # 16 x 8 KiB RAM banks = 128 KiB FRAM, header 0x149 = 0x04
        '-Wl-j'        # emit .noi debug info
        '-Wl-w'        # show linker warnings
        '-Wf--opt-code-speed'
    )
    $outExt = '.gb'
}

# lcc 4.5.0's NES makebin/makenes pass-through does not accept spaced
# arguments (e.g. "-Wn-b 1").  Patch the NES 2.0 header after linking.
#
# GBDK's default mapper 30 (UNROM-512) has no PRG-RAM, so the gameplay BSS
# cannot live at $6000.  Use the mapper-2 UNROM-512 board variant with 8 KiB
# battery-backed PRG-RAM instead (the USB-NES "UNROM 512 + Save RAM" mapping).
#
# The header must be NES 2.0, not iNES 1.0.  FCEUX's mapper 2 only maps
# $6000-$7FFF when the NES 2.0 PRG-NVRAM size field is non-zero, and the
# MiSTer NES core derives `prg_is_ram` from the same NES 2.0 field; the old
# iNES 1.0 byte 8 PRG-RAM size is ignored by both, which left the game's
# entire $6000 BSS mapped as open bus and hung the boot on a blank screen.
# NES 2.0 is also what the USB-NES mapper override descriptors use.
#
# Header layout:
#   byte 5  = 0x00  CHR-ROM banks (0; CHR-RAM size is byte 11)
#   byte 6  = 0x23  mapper 2 low nibble | battery | vertical mirroring
#   byte 7  = 0x08  NES 2.0 identifier, mapper high nibble 0
#   byte 8  = 0x00  mapper high nibble / submapper 0
#   byte 9  = 0x00  PRG/CHR size MSB
#   byte 10 = 0x70  8 KiB battery-backed PRG-NVRAM (64 << 7)
#   byte 11 = 0x07  8 KiB CHR-RAM (64 << 7)
#
# Horizontal arrangement (two 32x30 nametables side by side) is required by
# the phase-2 renderer: nametable 0 holds the vertically wrapping playfield
# ring, and nametable 1 holds the stationary top HUD selected by the
# scanline split.  In iNES terms this is vertical mirroring (flag 6 bit 0),
# which is also what the phase-1 ROM already used.
function Repair-NesHeader {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 16 -or
        $bytes[0] -ne 0x4E -or $bytes[1] -ne 0x45 -or
        $bytes[2] -ne 0x53 -or $bytes[3] -ne 0x1A) {
        throw "Not an iNES ROM: $Path"
    }

    $bytes[5] = 0x00    # CHR-ROM size LSB = 0 (CHR-RAM, see byte 11)
    $bytes[6] = 0x23    # mapper 2 | battery | vertical mirroring (two NTs side by side)
    $bytes[7] = 0x08    # NES 2.0 identifier; mapper high nibble 0
    $bytes[8] = 0x00    # mapper high nibble / submapper
    $bytes[9] = 0x00    # PRG-ROM/CHR-ROM size MSB
    $bytes[10] = 0x70   # 8 KiB battery-backed PRG-NVRAM (64 << 7)
    $bytes[11] = 0x07   # 8 KiB CHR-RAM (64 << 7)
    $bytes[12] = 0x00   # NTSC
    $bytes[13] = 0x00
    $bytes[14] = 0x00
    $bytes[15] = 0x00
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function Get-NoiSymbol {
    param(
        [string]$NoiPath,
        [string]$Name
    )

    $match = Select-String -Path $NoiPath -Pattern "^DEF $([regex]::Escape($Name)) 0x([0-9A-Fa-f]+)$"
    if (-not $match) {
        throw "Symbol $Name not found in $NoiPath"
    }
    return [Convert]::ToInt32($match.Matches[0].Groups[1].Value, 16)
}

function Assert-NesMemoryLayout {
    param(
        [string]$NoiPath,
        [string]$RomPath
    )

    $dataStart = Get-NoiSymbol -NoiPath $NoiPath -Name 's__DATA'
    $dataLen   = Get-NoiSymbol -NoiPath $NoiPath -Name 'l__DATA'
    $bssStart  = Get-NoiSymbol -NoiPath $NoiPath -Name 's__BSS'
    $bssLen    = Get-NoiSymbol -NoiPath $NoiPath -Name 'l__BSS'

    $dataEnd = $dataStart + $dataLen
    $bssEnd  = $bssStart + $bssLen

    if ($dataStart -ne 0x6000) {
        throw "NES _DATA starts at 0x$($dataStart.ToString('X4')), expected 0x6000"
    }
    if ($dataEnd -gt 0x7FF0) {
        throw "NES _DATA + _BSS overlap the save page: data ends at 0x$($dataEnd.ToString('X4'))"
    }
    if ($bssEnd -gt 0x7FF0) {
        throw "NES BSS overlaps the save page: ends at 0x$($bssEnd.ToString('X4')), limit 0x7FF0"
    }

    $free = 0x7FF0 - $bssEnd
    Write-Host ("RAM   {0}: DATA 0x{1:X4}-0x{2:X4}, BSS 0x{3:X4}-0x{4:X4}, {5} bytes free before save page" -f `
        (Split-Path $RomPath -Leaf), $dataStart, ($dataEnd - 1), $bssStart, ($bssEnd - 1), $free)
}

function Invoke-Variant {
    param(
        [string]$Name,
        [string]$RomName,
        [string]$SourceRoot,
        [string[]]$Defines
    )

    $objDir = Join-Path $build "obj\$Target-$Name"
    New-Item -ItemType Directory -Force -Path $objDir | Out-Null

    # Timestamp-incremental objects are safe inside a variant, but a changed
    # define list must force a full recompile of that variant.
    $defineKey = (($Defines + $portFlags) -join ' ')
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
            Write-Host "CC  [$Target/$Name] $rel"
            & $lcc @Defines @portFlags "-I$SourceRoot" -c -o $obj $src.FullName
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Compilation failed: $rel ($Target/$Name)"
                $failed = $true
                continue
            }
        }
        $objects += $obj
    }

    if ($failed) { throw "Build failed: $Target/$Name" }

    $out = Join-Path $romDir "$RomName$outExt"
    # Link NES builds through a -nes basename so lcc writes robbo-nes.noi /
    # robbo-nes.map instead of overwriting the Game Boy robbo.noi that the
    # existing test harness re-reads.  The final ROM is renamed to robbo.nes
    # afterwards.
    $linkOut = if ($Target -eq 'nes') {
        Join-Path $romDir "$RomName-nes$outExt"
    } else {
        $out
    }
    Write-Host "LD  [$Target/$Name] $out"
    & $lcc @Defines @portFlags "-I$SourceRoot" -Wl-m -o $linkOut @objects
    if ($LASTEXITCODE -ne 0) { throw "Link failed: $Target/$Name" }

    $map = Join-Path $romDir "$RomName.map"
    $noi = Join-Path $romDir "$RomName.noi"
    if ($Target -eq 'nes') {
        $map = Join-Path $romDir "$RomName-nes.map"
        $noi = Join-Path $romDir "$RomName-nes.noi"
        Repair-NesHeader -Path $linkOut
        if (-not (Test-Path $noi)) { throw "NES .noi not found: $noi" }
        Assert-NesMemoryLayout -NoiPath $noi -RomPath $out
        # lcc leaves the intermediate Intel-hex and raw ROM images behind.
        $linkBase = [System.IO.Path]::GetFileNameWithoutExtension($linkOut)
        Remove-Item -Force -ErrorAction SilentlyContinue -Path @(
            (Join-Path $romDir "$linkBase.ihx"),
            (Join-Path $romDir "$linkBase.rom")
        )
        Move-Item -Force $linkOut $out
    }

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
