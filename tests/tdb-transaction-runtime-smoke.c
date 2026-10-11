#include <sys/types.h>
#include <tdb.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    int flags = 0;
    if (argc == 2 && !strcmp(argv[1], "--mutex")) {
        if (!tdb_runtime_check_for_robust_mutexes()) {
            fprintf(stderr, "TDB robust mutex runtime unavailable\n");
            return 95;
        }
        flags = TDB_MUTEX_LOCKING;
    } else if (argc != 1) return 64;
    char path[] = "tdvp-tdb-XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0) return 1;
    close(fd);
    struct tdb_context *database = tdb_open(path, 0, flags, O_RDWR | O_CREAT, 0600);
    int status = 0;
    TDB_DATA key = {(unsigned char *)"key", 3};
    TDB_DATA value = {(unsigned char *)"TDVP-transaction", 16};
    if (!database) { status = 2; goto done; }
    if (tdb_transaction_start(database) || !tdb_transaction_active(database) ||
        tdb_store(database, key, value, TDB_INSERT) || tdb_transaction_cancel(database)) {
        status = 3; goto done;
    }
    if (tdb_exists(database, key)) { status = 4; goto done; }
    if (tdb_transaction_start(database) || tdb_store(database, key, value, TDB_INSERT) ||
        tdb_transaction_prepare_commit(database) || tdb_transaction_commit(database)) {
        status = 5; goto done;
    }
    if (tdb_close(database)) { database = NULL; status = 6; goto done; }
    database = tdb_open(path, 0, flags, O_RDWR, 0600);
    if (!database) { status = 7; goto done; }
    TDB_DATA fetched = tdb_fetch(database, key);
    status = !fetched.dptr || fetched.dsize != value.dsize || memcmp(fetched.dptr, value.dptr, value.dsize) ? 8 : 0;
    free(fetched.dptr);
    if (!status && tdb_check(database, NULL, NULL)) status = 9;
done:
    if (database) tdb_close(database);
    unlink(path);
    return status;
}
