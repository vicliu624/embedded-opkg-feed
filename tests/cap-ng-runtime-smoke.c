#include <cap-ng.h>
#include <linux/capability.h>
#include <string.h>

int main(void) {
    capng_clear(CAPNG_SELECT_BOTH);
    if (capng_have_capabilities(CAPNG_SELECT_CAPS) != CAPNG_NONE) return 1;
    if (capng_update(CAPNG_ADD, CAPNG_EFFECTIVE | CAPNG_PERMITTED, CAP_CHOWN)) return 2;
    if (!capng_have_capability(CAPNG_EFFECTIVE, CAP_CHOWN)) return 3;
    if (!capng_have_capability(CAPNG_PERMITTED, CAP_CHOWN)) return 4;
    if (capng_have_capability(CAPNG_EFFECTIVE, CAP_NET_ADMIN)) return 5;
    if (strcmp(capng_capability_to_name(CAP_CHOWN), "chown")) return 6;
    if (capng_name_to_capability("chown") != CAP_CHOWN) return 7;
    if (capng_update(CAPNG_DROP, CAPNG_EFFECTIVE | CAPNG_PERMITTED, CAP_CHOWN)) return 8;
    if (capng_have_capabilities(CAPNG_SELECT_CAPS) != CAPNG_NONE) return 9;
    return 0;
}
