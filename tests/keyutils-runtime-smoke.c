#include <keyutils.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    const char original[] = "tdvp-keyring-original";
    const char updated[] = "tdvp-keyring-updated";
    char buffer[64] = {0};
    if (strcmp(keyutils_version_string, "keyutils-1.6.3") ||
        strcmp(keyutils_build_string, "source-locked")) return 1;
    key_serial_t ring = keyctl_get_keyring_ID(KEY_SPEC_PROCESS_KEYRING, 1);
    if (ring < 0) {
        int error = errno;
        perror("private process keyring unavailable");
        return (error == ENOSYS || error == EPERM || error == EACCES) ? 95 : 2;
    }
    key_serial_t key = add_key("user", "tdvp-private-library-test", original, sizeof(original), ring);
    if (key < 0) return 3;
    int result = 0;
    if (keyctl_read(key, buffer, sizeof(buffer)) != sizeof(original) ||
        memcmp(buffer, original, sizeof(original))) result = 4;
    if (!result && keyctl_update(key, updated, sizeof(updated))) result = 5;
    if (!result && (keyctl_read(key, buffer, sizeof(buffer)) != sizeof(updated) ||
        memcmp(buffer, updated, sizeof(updated)))) result = 6;
    if (!result && keyctl_search(ring, "user", "tdvp-private-library-test", 0) != key) result = 7;
    if (keyctl_revoke(key) && !result) result = 8;
    if (keyctl_unlink(key, ring) && !result) result = 9;
    if (!result) puts("keyutils private process key create/read/update/search/revoke: PASS");
    return result;
}
