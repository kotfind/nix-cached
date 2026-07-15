/* Minimal reproducer: attempts to load libpsm2.
 * If built on an AVX machine but run on a non-AVX CPU,
 * the constructor in opa_time.c will trigger SIGILL. */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    /* Just try to dlopen libpsm2 -- the constructor runs, triggering SIGILL */
    void *handle = dlopen("libpsm2.so.2", RTLD_NOW);
    if (!handle) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 1;
    }
    printf("libpsm2 loaded successfully\n");
    dlclose(handle);
    return 0;
}
