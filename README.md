# KasekiResetState — rUGP "reset resume state" plugin

A tiny rUGP engine plugin (`.rpo`) that makes **はじめから (New Game) actually start
from the beginning** on modern Windows, and stops the random **text auto-advance
("auto-read")**, for âge visual novels built on the early **rUGP** engine
(developed/tested against *化石の歌 / Kaseki no Uta*).

## The problem

rUGP keeps all persistent state in the game's `Vmreg\` folder (there is **no**
registry key). On this old engine build, the *current-scenario bookmark* and the
*read-text (既読) flags* are stored in **`Vmreg\gdb.uuc`** (with a small companion
**`Vmreg\sedb.uuc`**). The engine restores that bookmark at boot, and はじめから on
this build never resets it — so "New Game" resumes your last position, and stale
read-flags make already-seen text auto-advance.

Manual save slots (`Vmreg\vmr*.uuc`) are **independent** and load correctly on their
own — they are never the problem.

## What this plugin does

At engine startup the plugin deletes the two state files:

```
<gameroot>\Vmreg\gdb.uuc
<gameroot>\Vmreg\sedb.uuc
```

…leaving `vmr*.uuc` saves untouched. Result:

- **はじめから always starts from the very beginning.**
- **No text auto-advance.**
- **Manual saves are preserved** and load normally via ロード.

The deletion runs in **both** `DllMain` (at `LoadLibrary` time) and the exported
`PluginThisLibrary` (when the engine calls it) — idempotent, so whichever the engine
reaches before reading its registry wins.

### Why it exports `PluginThisLibrary` / `GetPluginString`

rUGP `LoadLibrary`s every `Plugins\*.rpo` at startup. A plain DLL that registers no
RIO classes triggers the engine warning *"incompatible object definition plugin …"*.
Exporting `PluginThisLibrary` (a no-op stub) and `GetPluginString` (returns a
`const char*`) marks the file as a **library plugin** instead, suppressing that
warning. (The community `10WinCrashFix.rpo` uses the same two-export pattern.)

### Trade-offs (by design)

- The auto-resume / つづきから convenience is gone — **make a manual save before
  exiting** to continue later (use ロード).
- In-game config (text speed, volume) lives in `gdb.uuc`, so it **resets to defaults
  each launch**.

If you want to keep config + auto-resume and reset *only* on はじめから, that requires
hooking the engine's registry-read instead of deleting the file — out of scope here.

## Build

The host (rUGP) is a 32-bit process, so the plugin **must be 32-bit (i386)**.

### Prerequisites

A 32-bit MinGW C compiler. The easiest on Windows is llvm-mingw (multi-target,
links the old MSVCRT that this 2000-era host uses) via [scoop](https://scoop.sh):

```powershell
scoop install mingw-mstorsjo-llvm-msvcrt
```

This provides `i686-w64-mingw32-gcc`, `llvm-objdump`, and `llvm-readobj`.
Any `i686-w64-mingw32` GCC toolchain also works.

### Compile

```powershell
./build.ps1
```

or manually:

```powershell
i686-w64-mingw32-gcc -shared -O2 -s `
  -o KasekiResetState.rpo `
  src/kaseki_reset.c src/kaseki_reset.def -lkernel32
```

`build.ps1` also verifies the output is `IMAGE_FILE_MACHINE_I386` and exports exactly
`PluginThisLibrary` + `GetPluginString`.

### Linux / CI (cross-compile)

A `Makefile` cross-builds the same plugin with the mingw-w64 i686 toolchain:

```sh
sudo apt-get install -y gcc-mingw-w64-i686 binutils-mingw-w64-i686
make            # -> KasekiResetState.rpo
make loader     # -> tools/loader.exe (optional test harness)
```

GitHub Actions (`.github/workflows/build.yml`) runs this on every push / PR /
manual dispatch: it builds the `.rpo`, verifies it is a PE32 i386 DLL exporting
`PluginThisLibrary` + `GetPluginString`, and uploads it as a build artifact.

## Install

Copy the built plugin into the game's `Plugins\` folder (next to `riorha2.rpo`):

```
<game>\Plugins\KasekiResetState.rpo
```

Then launch the game's `.exe` normally. **Back up your `Vmreg\` folder first** if you
have progress you care about (though `vmr*.uuc` saves are preserved).

## Verify without the game

`tools/loader.c` builds a tiny 32-bit host that just `LoadLibrary`s the plugin
(running its `DllMain` exactly like the engine would), so you can confirm the deletion
logic against real files:

```powershell
i686-w64-mingw32-gcc -municode -O2 -s -o loader.exe tools/loader.c
./loader.exe "C:\path\to\game\Plugins\KasekiResetState.rpo"
```

Put dummy `gdb.uuc`/`sedb.uuc` in the game's `Vmreg\` first and confirm they vanish
while `vmr*.uuc` remain.

## Notes / implementation details

- Uses the **wide (W) Win32 APIs** throughout: install paths often contain Japanese
  characters (`化石の歌Dp`) that the ANSI APIs mangle on non-Japanese systems.
- The game root is derived from `GetModuleFileNameW(self)` → strip the filename and
  the `Plugins` component → append `\Vmreg\…`. No hard-coded paths.
- Only depends on `KERNEL32` (+ the CRT startup from `msvcrt`, already loaded by the
  host).

## Layout

```
src/kaseki_reset.c     plugin source
src/kaseki_reset.def    export list (PluginThisLibrary, GetPluginString)
tools/loader.c          32-bit LoadLibrary test harness
build.ps1               build + verify script
```
