#include <maxminddb.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 2) return 1;
    MMDB_s database;
    if (MMDB_open(argv[1], MMDB_MODE_MMAP, &database) != MMDB_SUCCESS) return 2;
    int status = 0, address_error = 0, database_error = 0;
    MMDB_lookup_result_s result = MMDB_lookup_string(&database, "81.2.69.160", &address_error, &database_error);
    if (address_error || database_error || !result.found_entry) { status = 3; goto done; }
    MMDB_entry_data_s data;
    if (MMDB_get_value(&result.entry, &data, "country", "iso_code", NULL) != MMDB_SUCCESS ||
        !data.has_data || data.type != MMDB_DATA_TYPE_UTF8_STRING || data.data_size != 2 ||
        memcmp(data.utf8_string, "GB", 2)) { status = 4; goto done; }
    MMDB_lookup_string(&database, "not-an-address", &address_error, &database_error);
    if (!address_error) status = 5;
done:
    MMDB_close(&database);
    return status;
}
