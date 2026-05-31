/* Tiny 32-bit test loader: LoadLibrary the plugin (runs its DllMain
   exactly like rUGP would), then unload. Path passed as argv[1]. */
#include <windows.h>
int wmain(int argc, wchar_t **argv)
{
    if (argc < 2) return 2;
    HMODULE h = LoadLibraryW(argv[1]);
    if (!h) return 1;
    FreeLibrary(h);
    return 0;
}
