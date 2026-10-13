/* Source-locked public headers consumed against the existing runtime provider. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sqlite3.h>

int main(void)
{
    assert(SQLITE_VERSION_NUMBER == 3048000);
    assert(sqlite3_libversion_number() == SQLITE_VERSION_NUMBER);
    assert(strcmp(sqlite3_libversion(), SQLITE_VERSION) == 0);
    sqlite3 *database = NULL;
    assert(sqlite3_open(":memory:", &database) == SQLITE_OK);
    assert(sqlite3_exec(database, "CREATE TABLE samples(id INTEGER, data BLOB); BEGIN", NULL, NULL, NULL) == SQLITE_OK);
    sqlite3_stmt *statement = NULL;
    const unsigned char payload[] = {0, 1, 0xff, 0x80, 0};
    assert(sqlite3_prepare_v2(database, "INSERT INTO samples VALUES(?, ?)", -1, &statement, NULL) == SQLITE_OK);
    assert(sqlite3_bind_int(statement, 1, 42) == SQLITE_OK);
    assert(sqlite3_bind_blob(statement, 2, payload, sizeof(payload), SQLITE_STATIC) == SQLITE_OK);
    assert(sqlite3_step(statement) == SQLITE_DONE);
    assert(sqlite3_finalize(statement) == SQLITE_OK);
    assert(sqlite3_prepare_v2(database, "SELECT id, data FROM samples", -1, &statement, NULL) == SQLITE_OK);
    assert(sqlite3_step(statement) == SQLITE_ROW);
    assert(sqlite3_column_int(statement, 0) == 42);
    assert(sqlite3_column_bytes(statement, 1) == sizeof(payload));
    assert(memcmp(sqlite3_column_blob(statement, 1), payload, sizeof(payload)) == 0);
    assert(sqlite3_finalize(statement) == SQLITE_OK);
    assert(sqlite3_exec(database, "ROLLBACK", NULL, NULL, NULL) == SQLITE_OK);
    assert(sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM samples", -1, &statement, NULL) == SQLITE_OK);
    assert(sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int(statement, 0) == 0);
    assert(sqlite3_finalize(statement) == SQLITE_OK);
    assert(sqlite3_close(database) == SQLITE_OK);
    puts("SQLite development: PASS existing 3.48.0 runtime, prepared binary data and rollback; no runtime rebuild");
    return 0;
}
