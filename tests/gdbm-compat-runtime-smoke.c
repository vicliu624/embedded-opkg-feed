#include <gdbm.h>
#include <ndbm.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char directory[] = "tdvp-gdbm-XXXXXX", native[256], compatible[256], path[272];
    if (!mkdtemp(directory)) return 1;
    snprintf(native, sizeof native, "%s/native", directory);
    snprintf(compatible, sizeof compatible, "%s/compatible", directory);
    GDBM_FILE database = NULL;
    DBM *legacy = NULL;
    datum key = {"key", 3}, value = {"TDVP-db", 7}, fetched;
    int status = 0;
    database = gdbm_open(native, 0, GDBM_NEWDB, 0600, NULL);
    if (!database) { status = 2; goto done; }
    if (gdbm_store(database, key, value, GDBM_INSERT) || gdbm_sync(database)) { status = 3; goto done; }
    gdbm_close(database);
    database = gdbm_open(native, 0, GDBM_READER, 0600, NULL);
    if (!database) { status = 4; goto done; }
    fetched = gdbm_fetch(database, key);
    status = !fetched.dptr || fetched.dsize != value.dsize || memcmp(fetched.dptr, value.dptr, value.dsize) ? 5 : 0;
    free(fetched.dptr);
    if (status) goto done;
    legacy = dbm_open(compatible, O_RDWR | O_CREAT | O_TRUNC, 0600);
    if (!legacy || dbm_store(legacy, key, value, DBM_INSERT)) { status = 6; goto done; }
    fetched = dbm_fetch(legacy, key);
    if (!fetched.dptr || fetched.dsize != value.dsize || memcmp(fetched.dptr, value.dptr, value.dsize)) { status = 7; goto done; }
    if (dbm_delete(legacy, key) || dbm_fetch(legacy, key).dptr) status = 8;
done:
    if (legacy) dbm_close(legacy);
    if (database) gdbm_close(database);
    unlink(native);
    const char *suffixes[] = {"", ".dir", ".pag", ".db"};
    for (unsigned i = 0; i < sizeof suffixes / sizeof suffixes[0]; ++i) {
        snprintf(path, sizeof path, "%s%s", compatible, suffixes[i]);
        unlink(path);
    }
    if (rmdir(directory) && !status) status = 9;
    return status;
}
