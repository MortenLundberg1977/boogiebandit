# Wraps a .prg in a T64 tape image (one file), for emulators and SD-card
# loaders that take .t64.
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_t64.ps1 build\boogie.prg build\boogiebandit.t64 BOOGIE "BOOGIE BANDIT"
param([Parameter(Mandatory)][string]$Prg, [Parameter(Mandatory)][string]$Out,
      [string]$Name = "BOOGIE", [string]$TapeName = "BOOGIE BANDIT")

$ErrorActionPreference = "Stop"
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Prg).Path)
if ($bytes.Length -lt 3) { throw "$Prg is too short" }
$start = $bytes[0] + 256 * $bytes[1]
$len = $bytes.Length - 2
$end = $start + $len
if ($end -gt 0x10000) { throw "program runs past `$ffff" }

$t = New-Object byte[] (0x60 + $len)
function Put-Text([int]$at, [string]$s, [int]$size, [byte]$pad) {
    for ($i = 0; $i -lt $size; $i++) {
        $t[$at + $i] = if ($i -lt $s.Length) { [byte][char]$s[$i] } else { $pad }
    }
}
function Put-Word([int]$at, [int]$v) { $t[$at] = $v -band 0xff; $t[$at + 1] = ($v -shr 8) -band 0xff }

# header
Put-Text 0x00 "C64S tape image file" 32 0
Put-Word 0x20 0x0101                     # version
Put-Word 0x22 1                          # directory entries
Put-Word 0x24 1                          # used entries
Put-Text 0x28 $TapeName.ToUpper() 24 0x20
# the one directory entry
$t[0x40] = 1                             # normal tape file
$t[0x41] = 0x82                          # PRG
Put-Word 0x42 $start
Put-Word 0x44 ($end -band 0xffff)
Put-Word 0x48 0x60                       # where the data starts
Put-Word 0x4a 0
Put-Text 0x50 $Name.ToUpper() 16 0x20    # uppercase ASCII = PETSCII capitals
[Array]::Copy($bytes, 2, $t, 0x60, $len)

[System.IO.File]::WriteAllBytes((Join-Path (Get-Location) $Out), $t)
"{0}: {1} bytes, `${2:x4}-`${3:x4}" -f $Out, $len, $start, ($end - 1)
