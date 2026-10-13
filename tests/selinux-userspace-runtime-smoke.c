#include <selinux/context.h>
#include <sepol/policydb.h>
#include <sepol/handle.h>
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>

int main(void)
{
    /* Parse only private in-memory data; never load policy or relabel files. */
    context_t context = context_new("user_u:role_r:type_t:s0");
    if (!context) return 1;
    if (strcmp(context_user_get(context), "user_u") ||
        strcmp(context_role_get(context), "role_r") ||
        strcmp(context_type_get(context), "type_t")) return 2;
    if (context_type_set(context, "updated_t") ||
        strcmp(context_type_get(context), "updated_t")) return 3;
    context_free(context);
    sepol_handle_t *handle = sepol_handle_create();
    if (!handle) return 4;
    sepol_policydb_t *policy = NULL;
    if (sepol_policydb_create(&policy) || !policy) return 5;
    sepol_policydb_free(policy);
    sepol_handle_destroy(handle);
    void *library = dlopen("libsepol.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!library) return 6;
    if (!dlsym(library, "sepol_policydb_to_image") ||
        !dlsym(library, "sepol_policy_kern_vers_max")) return 7;
    if (dlclose(library)) return 8;
    puts("SELinux userspace context, policy object and dynamic sepol provider: PASS");
    return 0;
}
