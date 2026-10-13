#include <libpsl.h>
#include <string.h>

int main(void) {
    const psl_ctx_t *ctx = psl_builtin();
    if (!ctx || psl_suffix_count(ctx) < 1000) return 1;
    if (!psl_is_public_suffix(ctx, "co.uk")) return 2;
    if (psl_is_public_suffix(ctx, "example.co.uk")) return 3;
    const char *domain = psl_registrable_domain(ctx, "www.example.co.uk");
    if (!domain || strcmp(domain, "example.co.uk")) return 4;
    if (psl_is_cookie_domain_acceptable(ctx, "www.example.co.uk", "co.uk"))
        return 5;
    if (!psl_is_cookie_domain_acceptable(ctx, "www.example.co.uk", "example.co.uk"))
        return 6;
    return 0;
}
