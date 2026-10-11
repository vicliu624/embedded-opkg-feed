/* Decode the upstream sweep fixture and check deterministic seek-to-start. */
#include <assert.h>
#include <mpg123.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    assert(argc == 2 && mpg123_init() == MPG123_OK);
    int error = 0;
    mpg123_handle *decoder = mpg123_new(NULL, &error);
    assert(decoder && error == MPG123_OK);
    assert(mpg123_open(decoder, argv[1]) == MPG123_OK);
    unsigned char buffer[8192], first[8192];
    size_t first_size = 0, total = 0, bytes;
    int status;
    do {
        bytes = 0;
        status = mpg123_read(decoder, buffer, sizeof(buffer), &bytes);
        assert(status == MPG123_OK || status == MPG123_NEW_FORMAT || status == MPG123_DONE);
        if (bytes && !first_size) {
            first_size = bytes;
            memcpy(first, buffer, bytes);
        }
        total += bytes;
    } while (status != MPG123_DONE);
    assert(first_size > 0 && total > 44100);
    long rate;
    int channels, encoding;
    assert(mpg123_getformat(decoder, &rate, &channels, &encoding) == MPG123_OK);
    assert(rate > 0 && (channels == 1 || channels == 2));
    assert(encoding == MPG123_ENC_SIGNED_16);
    assert(mpg123_seek(decoder, 0, SEEK_SET) == 0);
    bytes = 0;
    status = mpg123_read(decoder, buffer, first_size, &bytes);
    if (status == MPG123_NEW_FORMAT && !bytes)
        status = mpg123_read(decoder, buffer, first_size, &bytes);
    assert(status == MPG123_OK && bytes == first_size);
    assert(memcmp(buffer, first, first_size) == 0);
    mpg123_close(decoder);
    mpg123_delete(decoder);
    mpg123_exit();
    printf("mpg123: PASS %zu decoded PCM bytes, %ld Hz, %d channels, exact seek replay\n", total, rate, channels);
    return 0;
}
