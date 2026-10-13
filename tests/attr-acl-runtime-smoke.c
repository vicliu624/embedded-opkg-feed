#include <attr/attributes.h>
#include <sys/acl.h>
#include <acl/libacl.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char path[] = "tdvp-attr-acl-XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0) return 1;
    int status = 0;
    const char value[] = "TDVP extended attribute";
    char output[128];
    int length = sizeof(output);
    acl_t acl = NULL, loaded = NULL;
    if (attr_set(path, "tdvp.smoke", value, sizeof(value), 0)) { status = 2; goto done; }
    if (attr_get(path, "tdvp.smoke", output, &length, 0) || length != sizeof(value) || memcmp(output, value, sizeof(value))) { status = 3; goto done; }
    if (attr_remove(path, "tdvp.smoke", 0)) { status = 4; goto done; }
    acl = acl_from_text("u::rw-,g::r--,o::---");
    if (!acl || acl_valid(acl)) { status = 5; goto done; }
    if (acl_set_fd(fd, acl)) { status = 6; goto done; }
    loaded = acl_get_fd(fd);
    if (!loaded || acl_cmp(acl, loaded)) { status = 7; goto done; }
done:
    if (acl) acl_free(acl);
    if (loaded) acl_free(loaded);
    close(fd);
    unlink(path);
    return status;
}
