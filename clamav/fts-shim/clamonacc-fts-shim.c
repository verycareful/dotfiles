/* clamonacc-fts-shim: make clamonacc's DDD work on glibc >= 2.44.
 *
 * glibc 2.44 switched fts(3) to the gnulib implementation. When fts_open() is
 * given a NULL comparator, gnulib defers stat() and fts_children() returns
 * every entry as FTS_NSOK. clamonacc (onas_ht_add_hierarchy, hash.c) only
 * records children whose fts_info == FTS_D, so it records none: no
 * subdirectory is ever watched and every OnAccessExcludePath fails with
 * "ClamInotif: can't exclude". Passing any comparator makes gnulib stat
 * eagerly again, restoring the classic FTS_D result.
 *
 * Build:   gcc -O2 -fPIC -shared -o clamonacc-fts-shim.so clamonacc-fts-shim.c -ldl
 * Use:     Environment=LD_PRELOAD=/usr/local/lib/clamonacc-fts-shim.so  (clamonacc unit only)
 * The .so MUST be root-owned and not user-writable: it is preloaded into a root process.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fts.h>
#include <stddef.h>

typedef int (*fts_cmp_t)(const FTSENT **, const FTSENT **);
typedef FTS *(*fts_open_t)(char *const *, int, fts_cmp_t);

static int noop_cmp(const FTSENT **a, const FTSENT **b) { (void)a; (void)b; return 0; }

FTS *fts_open(char *const *path_argv, int options, fts_cmp_t compar)
{
    static fts_open_t real_fts_open = NULL;
    if (!real_fts_open) real_fts_open = (fts_open_t)dlsym(RTLD_NEXT, "fts_open");
    return real_fts_open(path_argv, options, compar ? compar : noop_cmp);
}

/* LFS spelling (fts64_open) is the same entry point on x86_64; export it too. */
FTS64 *fts64_open(char *const *path_argv, int options, int (*compar)(const FTSENT64 **, const FTSENT64 **))
{
    return (FTS64 *)fts_open(path_argv, options, (fts_cmp_t)compar);
}
