/*
 * Silent deaths on Switch: abort(), exit() and whatever goes to stderr.
 *
 * newlib's abort() returns to the HOME menu without a word (measured on the first
 * boot of the SDK, see switch_libc_supplement.c). rex::FatalError ends there, as do
 * std::terminate (an uncaught exception, a std::thread destroyed without join) and
 * Mesa's aborts. And they all warn on stderr first, which goes nowhere in an NRO.
 *
 * It has to be in the executable, in rexglue_switch_startup, and not in a library:
 * the definition of abort has to reach the link before the one in libc.a to
 * replace it.
 *
 *   stderr  -> <NRO folder>/logs/rex/rex_stderr.log, unbuffered, rewritten on every boot
 *   abort() -> <NRO folder>/logs/rex/rex_crash.log with the stack, and error 2345-0101
 *   exit()  -> the same, error 2345-0103. The orderly shutdown does not go through exit()
 *              (see windowed_app_main_switch.cpp), so getting here means some library
 *              decided to end the process on its own.
 *
 * The rexglue logs go to <NRO folder>/logs/rex/ and not to sdmc:/switch/, so they do not mix with
 * those of other programs or with the game's, which go to <NRO folder>/logs/. The folder comes from
 * argv[0], which libnx fills in before the constructors. Without argv[0], sdmc:/switch/ is used.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include <switch.h>

/* Filled in by libnx (argv.c), which does not declare them in its headers. */
extern int __system_argc;
extern char** __system_argv;

/* Ends in '/'. Computed once at startup and never changes: the fault handler reads it without allocating memory. */
static char g_rex_log_dir[FS_MAX_PATH] = "sdmc:/switch/";

const char* RexSwitchLogDir(void) {
    return g_rex_log_dir;
}

static void RexSwitchInitLogDir(void) {
    if (__system_argc < 1 || !__system_argv || !__system_argv[0]) {
        return;
    }
    const char* nro = __system_argv[0];
    const char* barra = strrchr(nro, '/');
    if (!barra) {
        return;
    }
    /* without a device ("/switch/..."), the SD one: the path must also work for fsdevTranslatePath */
    const char* dispositivo = strchr(nro, ':') ? "" : "sdmc:";
    char dir[FS_MAX_PATH];
    int n = snprintf(dir, sizeof(dir), "%s%.*slogs", dispositivo, (int)(barra - nro + 1), nro);
    if (n <= 0 || (size_t)n + sizeof("/rex/") > sizeof(dir)) {
        return;
    }
    mkdir(dir, 0777);
    strcat(dir, "/rex");
    mkdir(dir, 0777);
    struct stat st;
    if (stat(dir, &st) == 0 && S_ISDIR(st.st_mode)) {
        strcat(dir, "/");
        strcpy(g_rex_log_dir, dir);
    }
}

void RexSwitchCrashLog(const char* reason, const ThreadExceptionDump* ctx, u64 stack, u64 pc);

void abort(void) {
    RexSwitchCrashLog("abort()", NULL, (u64)__builtin_frame_address(0),
                      (u64)__builtin_return_address(0));
    diagAbortWithResult(MAKERESULT(Module_Libnx, 101));
}

static void RexSwitchExitHook(void) {
    RexSwitchCrashLog("exit() fuera del cierre ordenado", NULL, (u64)__builtin_frame_address(0),
                      (u64)__builtin_return_address(0));
    diagAbortWithResult(MAKERESULT(Module_Libnx, 103));
}

/*
 * Priority 101, the first one allowed: before any static constructor of the
 * SDK, which can also die. The SD is already mounted: __appInit runs before the
 * constructors.
 */
__attribute__((constructor(101)))
static void RexSwitchCrashHooksInit(void) {
    RexSwitchInitLogDir();
    char ruta[FS_MAX_PATH];
    snprintf(ruta, sizeof(ruta), "%srex_stderr.log", g_rex_log_dir);
    if (freopen(ruta, "w", stderr)) {
        setvbuf(stderr, NULL, _IONBF, 0);
    }
    atexit(RexSwitchExitHook);
}

/* PATCH(cola): attribute large heap allocations to their callers. Allocations >= 512 KB are
 * recorded (live set) by return address, summarized by RexColaHeapDump from the profiler. */
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdatomic.h>

extern void* __real_malloc(size_t);
extern void* __real_memalign(size_t, size_t);
extern void* __real_aligned_alloc(size_t, size_t);
extern int __real_posix_memalign(void**, size_t, size_t);
extern void* __real_calloc(size_t, size_t);
extern void* __real_realloc(void*, size_t);
extern void __real_free(void*);

#define COLA_TH (512u * 1024u)
#define COLA_SLOTS 1024
static struct { _Atomic(uintptr_t) ptr; size_t size; uintptr_t caller; } g_cola_live[COLA_SLOTS];

static void cola_record(void* p, size_t size, uintptr_t caller) {
    if (!p || size < COLA_TH) return;
    size_t h = ((uintptr_t)p >> 12) & (COLA_SLOTS - 1);
    for (int i = 0; i < 64; ++i, h = (h + 1) & (COLA_SLOTS - 1)) {
        uintptr_t e = 0;
        if (atomic_compare_exchange_strong(&g_cola_live[h].ptr, &e, (uintptr_t)p)) {
            g_cola_live[h].size = size;
            g_cola_live[h].caller = caller;
            return;
        }
    }
}
static void cola_forget(void* p) {
    if (!p) return;
    size_t h = ((uintptr_t)p >> 12) & (COLA_SLOTS - 1);
    for (int i = 0; i < 64; ++i, h = (h + 1) & (COLA_SLOTS - 1)) {
        uintptr_t e = (uintptr_t)p;
        if (atomic_compare_exchange_strong(&g_cola_live[h].ptr, &e, 0)) return;
    }
}

void* __wrap_malloc(size_t n) { void* p = __real_malloc(n); cola_record(p, n, (uintptr_t)__builtin_return_address(0)); return p; }
void* __wrap_memalign(size_t a, size_t n) { void* p = __real_memalign(a, n); cola_record(p, n, (uintptr_t)__builtin_return_address(0)); return p; }
void* __wrap_aligned_alloc(size_t a, size_t n) { void* p = __real_aligned_alloc(a, n); cola_record(p, n, (uintptr_t)__builtin_return_address(0)); return p; }
int __wrap_posix_memalign(void** out, size_t a, size_t n) { int r = __real_posix_memalign(out, a, n); if (r == 0) cola_record(*out, n, (uintptr_t)__builtin_return_address(0)); return r; }
void* __wrap_calloc(size_t c, size_t n) { void* p = __real_calloc(c, n); cola_record(p, c * n, (uintptr_t)__builtin_return_address(0)); return p; }
void* __wrap_realloc(void* old, size_t n) { void* p = __real_realloc(old, n); if (p != old) cola_forget(old); cola_record(p, n, (uintptr_t)__builtin_return_address(0)); return p; }
void __wrap_free(void* p) { cola_forget(p); __real_free(p); }

/* Live big allocations grouped by caller: top 8 by total size. */
void RexColaHeapDump(FILE* f, uint64_t image_base) {
    uintptr_t ck[64] = {0}; unsigned long long cs[64] = {0}; unsigned cn[64] = {0}; int nc = 0;
    for (int i = 0; i < COLA_SLOTS; ++i) {
        uintptr_t p = atomic_load(&g_cola_live[i].ptr);
        if (!p) continue;
        int j = 0;
        for (; j < nc; ++j) if (ck[j] == g_cola_live[i].caller) break;
        if (j == nc) { if (nc == 64) continue; ck[nc++] = g_cola_live[i].caller; }
        cs[j] += g_cola_live[i].size; cn[j]++;
    }
    fprintf(f, "     heap grande (>=512 KB) vivo por llamador:");
    for (int k = 0; k < 8; ++k) {
        int best = -1;
        for (int j = 0; j < nc; ++j) if (cs[j] && (best < 0 || cs[j] > cs[best])) best = j;
        if (best < 0) break;
        fprintf(f, " imagen+0x%llx %lluMB(x%u)", (unsigned long long)(ck[best] - image_base), cs[best] >> 20, cn[best]);
        cs[best] = 0;
    }
    fprintf(f, "\n");
}