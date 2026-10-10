#define _GNU_SOURCE
#include <dlfcn.h>
#include <rpcsvc/ypclnt.h>
#include <rpcsvc/yp_prot.h>
#include <string.h>

int main(void) {
    void *old = dlopen("libnsl.so.1", RTLD_NOW | RTLD_LOCAL);
    void *modern = dlopen("libnsl.so.3", RTLD_NOW | RTLD_LOCAL);
    if (!old || !modern) return 1;
    const char *(*old_error)(int) = (const char *(*)(int))dlvsym(old, "yperr_string", "GLIBC_2.27");
    const char *(*new_error)(int) = (const char *(*)(int))dlsym(modern, "yperr_string");
    int (*map_error)(int) = (int (*)(int))dlsym(modern, "ypprot_err");
    if (!old_error || !new_error || !map_error || old_error == new_error) return 2;
    if (map_error(YP_NOMAP) != YPERR_MAP || map_error(YP_TRUE) != YPERR_SUCCESS) return 3;
    const char *first = old_error(YPERR_MAP), *second = new_error(YPERR_MAP);
    if (!first || !second || !*first || !*second) return 4;
    if (dlclose(modern) || dlclose(old)) return 5;
    return 0;
}
