#include <snappy-c.h>
#include <string.h>

int main(void) {
    const char input[] = "TDVP snappy compression roundtrip";
    char compressed[256], decoded[256];
    size_t encoded_size = sizeof(compressed), decoded_size = sizeof(decoded), expected;
    if (snappy_compress(input, sizeof(input), compressed, &encoded_size) != SNAPPY_OK) return 1;
    if (snappy_validate_compressed_buffer(compressed, encoded_size) != SNAPPY_OK) return 2;
    if (snappy_uncompressed_length(compressed, encoded_size, &expected) != SNAPPY_OK || expected != sizeof(input)) return 3;
    if (snappy_uncompress(compressed, encoded_size, decoded, &decoded_size) != SNAPPY_OK || decoded_size != sizeof(input) || memcmp(input, decoded, sizeof(input))) return 4;
    if (snappy_validate_compressed_buffer(compressed, encoded_size - 1) == SNAPPY_OK) return 5;
    decoded_size = 1;
    if (snappy_uncompress(compressed, encoded_size, decoded, &decoded_size) != SNAPPY_BUFFER_TOO_SMALL) return 6;
    return 0;
}
