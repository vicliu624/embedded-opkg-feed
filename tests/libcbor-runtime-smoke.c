#include <cbor.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    cbor_item_t *value = cbor_build_string("TDVP CBOR roundtrip");
    unsigned char *encoded = NULL;
    size_t capacity = 0;
    size_t length = cbor_serialize_alloc(value, &encoded, &capacity);
    if (!length || length > capacity) return 1;
    struct cbor_load_result result;
    cbor_item_t *decoded = cbor_load(encoded, length, &result);
    if (!decoded || result.error.code != CBOR_ERR_NONE || result.read != length)
        return 2;
    if (!cbor_isa_string(decoded) || cbor_string_length(decoded) != 19 ||
        memcmp(cbor_string_handle(decoded), "TDVP CBOR roundtrip", 19)) return 3;
    cbor_decref(&decoded);
    decoded = cbor_load(encoded, length - 1, &result);
    if (decoded || result.error.code == CBOR_ERR_NONE) return 4;
    free(encoded);
    cbor_decref(&value);
    return 0;
}
