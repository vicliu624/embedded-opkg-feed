#include <zip.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    int error = 0;
    char buffer[128] = {0};
    if (argc != 3) return 64;
    if (!strncmp(argv[2], "create-", 7)) {
        zip_t *created = zip_open(argv[1], ZIP_CREATE | ZIP_TRUNCATE, &error);
        if (!created) return 5;
        const char payload[] = "TDVP LZMA bounded decoder test";
        zip_source_t *source = zip_source_buffer(created, payload, sizeof(payload) - 1, 0);
        if (!source) return 6;
        zip_int64_t index = zip_file_add(created, "payload.txt", source, ZIP_FL_ENC_UTF_8);
        if (index < 0) return 7;
        zip_int32_t method = !strcmp(argv[2], "create-lzma") ? ZIP_CM_LZMA : ZIP_CM_DEFLATE;
        if (zip_set_file_compression(created, (zip_uint64_t)index, method, 6) < 0) return 8;
        if (zip_close(created) < 0) return 9;
        puts("libzip target ZIP creation: PASS");
        return 0;
    }
    zip_t *archive = zip_open(argv[1], ZIP_RDONLY, &error);
    if (!archive) return 1;
    zip_file_t *file = zip_fopen(archive, "payload.txt", 0);
    if (!file) { zip_discard(archive); return 2; }
    zip_int64_t length = zip_fread(file, buffer, sizeof(buffer));
    if (strcmp(argv[2], "reject") == 0) {
        /* libzip maps header-time decoder failures to COMPRESSED_DATA; its
         * later decoder path maps MEMLIMIT_ERROR to MEMORY. */
        int code = zip_error_code_zip(zip_file_get_error(file));
        if (length >= 0 || (code != ZIP_ER_MEMORY && code != ZIP_ER_COMPRESSED_DATA)) return 3;
        printf("libzip oversized LZMA dictionary: rejected (%s)\n", zip_file_strerror(file));
    } else {
        const char expected[] = "TDVP LZMA bounded decoder test";
        if (length != sizeof(expected) - 1 || memcmp(buffer, expected, sizeof(expected) - 1)) return 4;
        puts("libzip ZIP/LZMA payload: PASS exact decoded bytes");
    }
    zip_fclose(file);
    zip_discard(archive);
    return 0;
}
