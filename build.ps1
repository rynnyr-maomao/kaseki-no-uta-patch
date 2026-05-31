#requires -version 5
<#
    Build KasekiResetState.rpo (32-bit rUGP plugin) and verify the output.
    Needs an i686-w64-mingw32 GCC toolchain on PATH, or installed via:
        scoop install mingw-mstorsjo-llvm-msvcrt
#>
[CmdletBinding()]
param(
    [switch]$Loader   # also build tools/loader.exe test harness
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Find-Tool([string]$name) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $scoopBin = Join-Path $env:USERPROFILE 'scoop\apps\mingw-mstorsjo-llvm-msvcrt\current\bin'
    $p = Join-Path $scoopBin $name
    if (Test-Path $p) { return $p }
    return $null
}

$gcc = Find-Tool 'i686-w64-mingw32-gcc.exe'
if (-not $gcc) { $gcc = Find-Tool 'i686-w64-mingw32-gcc' }
if (-not $gcc) {
    throw "i686-w64-mingw32-gcc not found. Install a 32-bit MinGW toolchain, e.g. 'scoop install mingw-mstorsjo-llvm-msvcrt'."
}
Write-Host "Using compiler: $gcc"

$out = Join-Path $root 'KasekiResetState.rpo'
& $gcc -shared -O2 -s -o $out `
    (Join-Path $root 'src\kaseki_reset.c') `
    (Join-Path $root 'src\kaseki_reset.def') `
    -lkernel32
if ($LASTEXITCODE -ne 0) { throw "Build failed ($LASTEXITCODE)" }
Write-Host "Built: $out ($((Get-Item $out).Length) bytes)" -ForegroundColor Green

# --- verify (best effort; needs llvm-readobj) ---
$readobj = Find-Tool 'llvm-readobj.exe'
if ($readobj) {
    $hdr = & $readobj --file-headers $out 2>&1
    $exp = & $readobj --coff-exports $out 2>&1
    if (($hdr | Select-String 'IMAGE_FILE_MACHINE_I386')) {
        Write-Host "  arch: i386 (32-bit) OK" -ForegroundColor Green
    } else {
        Write-Warning "Output is NOT i386 — rUGP (32-bit) cannot load it."
    }
    $names = ($exp | Select-String 'Name:').Line -join ' '
    if ($names -match 'PluginThisLibrary' -and $names -match 'GetPluginString') {
        Write-Host "  exports: PluginThisLibrary + GetPluginString OK" -ForegroundColor Green
    } else {
        Write-Warning "Expected exports missing — engine may warn 'incompatible object definition plugin'. Got: $names"
    }
} else {
    Write-Warning "llvm-readobj not found; skipped verification."
}

if ($Loader) {
    $lo = Join-Path $root 'tools\loader.exe'
    & $gcc -municode -O2 -s -o $lo (Join-Path $root 'tools\loader.c')
    if ($LASTEXITCODE -ne 0) { throw "loader build failed ($LASTEXITCODE)" }
    Write-Host "Built: $lo" -ForegroundColor Green
}

Write-Host "`nInstall: copy KasekiResetState.rpo into your game's Plugins\ folder." -ForegroundColor Cyan
