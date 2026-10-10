#include <libfdt.h>
#include <lmdb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(void) {
    union { uint64_t alignment; unsigned char bytes[4096]; } tree;
    if (fdt_create_empty_tree(tree.bytes, sizeof(tree.bytes))) return 1;
    int node = fdt_add_subnode(tree.bytes, 0, "fixture");
    if (node < 0 || fdt_setprop_string(tree.bytes, node, "status", "okay") ||
        fdt_setprop_u32(tree.bytes, node, "value", 42) || fdt_pack(tree.bytes)) return 2;
    node = fdt_path_offset(tree.bytes, "/fixture");
    int length = 0;
    const fdt32_t *value = fdt_getprop(tree.bytes, node, "value", &length);
    if (!value || length != 4 || fdt32_to_cpu(*value) != 42 || fdt_check_header(tree.bytes)) return 3;
    tree.bytes[0] ^= 1;
    if (fdt_check_header(tree.bytes) != -FDT_ERR_BADMAGIC) return 4;
    puts("libfdt memory tree roundtrip and malformed header rejection: PASS");

    char directory[] = "tdvp-lmdb-fixture-XXXXXX";
    if (!mkdtemp(directory)) return 5;
    MDB_env *environment = NULL;
    MDB_txn *transaction = NULL;
    MDB_dbi database;
    const char key_text[] = "result", value_text[] = "cpu1-result";
    MDB_val key = {sizeof(key_text), (void *)key_text};
    MDB_val content = {sizeof(value_text), (void *)value_text}, read;
    int result;
    if ((result = mdb_env_create(&environment)) ||
        (result = mdb_env_set_mapsize(environment, 1024 * 1024)) ||
        (result = mdb_env_open(environment, directory, 0, 0600))) {
        fprintf(stderr, "LMDB environment initialization: %d %s\n", result, mdb_strerror(result));
        if (environment) mdb_env_close(environment);
        return 6;
    }
    if (mdb_txn_begin(environment, NULL, 0, &transaction) ||
        mdb_dbi_open(transaction, NULL, 0, &database) || mdb_put(transaction, database, &key, &content, 0)) return 7;
    mdb_txn_abort(transaction);
    if (mdb_txn_begin(environment, NULL, MDB_RDONLY, &transaction) ||
        mdb_dbi_open(transaction, NULL, 0, &database) || mdb_get(transaction, database, &key, &read) != MDB_NOTFOUND) return 8;
    mdb_txn_abort(transaction);
    if (mdb_txn_begin(environment, NULL, 0, &transaction) ||
        mdb_dbi_open(transaction, NULL, 0, &database) || mdb_put(transaction, database, &key, &content, 0) ||
        mdb_txn_commit(transaction) || mdb_env_sync(environment, 1)) return 9;
    mdb_env_close(environment);
    if (mdb_env_create(&environment) || mdb_env_open(environment, directory, 0, 0600) ||
        mdb_txn_begin(environment, NULL, MDB_RDONLY, &transaction) ||
        mdb_dbi_open(transaction, NULL, 0, &database) || mdb_get(transaction, database, &key, &read) ||
        read.mv_size != sizeof(value_text) || memcmp(read.mv_data, value_text, sizeof(value_text))) return 10;
    mdb_txn_abort(transaction);
    mdb_env_close(environment);
    char file[128];
    snprintf(file, sizeof(file), "%s/data.mdb", directory);
    if (unlink(file)) return 11;
    snprintf(file, sizeof(file), "%s/lock.mdb", directory);
    if (unlink(file) || rmdir(directory)) return 12;
    puts("LMDB transaction abort, commit and reopen persistence: PASS");
    return 0;
}
