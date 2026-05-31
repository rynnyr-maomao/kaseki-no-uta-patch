/* ============================================================
 *  Kaseki no Uta (rUGP) — "reset resume state" plugin
 *
 *  Dropped into the game's Plugins\ folder as a .rpo, the rUGP
 *  engine LoadLibrary's it at startup and (because it exports
 *  PluginThisLibrary / GetPluginString) treats it as a "library
 *  plugin" rather than an object-definition plugin, so no
 *  "incompatible object definition plugin" warning is shown.
 *
 *  We delete the two Vmreg state files that hold the current-
 *  scenario bookmark + stale read-flags:
 *      <gameroot>\Vmreg\gdb.uuc
 *      <gameroot>\Vmreg\sedb.uuc
 *  in BOTH DllMain (at load) and PluginThisLibrary (when the
 *  engine calls it) — idempotent, so whichever runs before the
 *  engine reads its registry wins. Effect: はじめから always
 *  starts fresh, no text auto-advance. Manual saves
 *  (Vmreg\vmr*.uuc) are untouched and load normally.
 *
 *  Wide (W) APIs are used throughout because the install path
 *  contains Japanese characters that the ANSI APIs would mangle.
 * ============================================================ */
#include <windows.h>

static HINSTANCE g_self = NULL;

static void delete_in_vmreg(const WCHAR *root, const WCHAR *leaf)
{
    WCHAR f[MAX_PATH];
    lstrcpynW(f, root, MAX_PATH);
    lstrcatW(f, L"\\Vmreg\\");
    lstrcatW(f, leaf);
    DeleteFileW(f);                 /* ignore errors (e.g. already gone) */
}

static void clear_resume_state(void)
{
    WCHAR path[MAX_PATH];
    DWORD n;

    if (g_self == NULL)
        return;

    n = GetModuleFileNameW(g_self, path, MAX_PATH);
    if (n == 0 || n >= MAX_PATH)
        return;

    /* path = <gameroot>\Plugins\<thisfile>.rpo
       Strip the filename (back up to the last backslash). */
    int i = (int)n;
    while (i > 0 && path[i - 1] != L'\\') i--;
    if (i == 0) return;
    int sep_plugins = i - 1;        /* '\' between Plugins and filename */

    /* Strip the "Plugins" component to reach <gameroot>. */
    int k = sep_plugins;
    while (k > 0 && path[k - 1] != L'\\') k--;
    if (k == 0) return;
    path[k - 1] = L'\0';            /* path = <gameroot> */

    delete_in_vmreg(path, L"gdb.uuc");
    delete_in_vmreg(path, L"sedb.uuc");
}

/* --- rUGP library-plugin entry points (exported via the .def) --- */
void PluginThisLibrary(void)
{
    clear_resume_state();
}

const char *GetPluginString(void)
{
    return "KasekiResetState 1.0 - clears Vmreg resume state";
}

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        g_self = hinst;
        DisableThreadLibraryCalls(hinst);
        clear_resume_state();
    }
    return TRUE;
}
