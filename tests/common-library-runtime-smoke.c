#include <brotli/encode.h>
#include <brotli/decode.h>
#include <rhash.h>
#include <idn2.h>
#include <histedit.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const unsigned char input[] = "TDVP compression and hashing roundtrip";
    unsigned char compressed[256], decoded[256], digest[32];
    size_t compressed_size = sizeof(compressed), decoded_size = sizeof(decoded);
    if (!BrotliEncoderCompress(5, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC,
                              sizeof(input), input, &compressed_size, compressed)) return 1;
    if (BrotliDecoderDecompress(compressed_size, compressed, &decoded_size, decoded)
        != BROTLI_DECODER_RESULT_SUCCESS) return 2;
    if (decoded_size != sizeof(input) || memcmp(input, decoded, sizeof(input))) return 3;
    decoded_size = sizeof(decoded);
    if (BrotliDecoderDecompress(compressed_size - 1, compressed, &decoded_size, decoded)
        == BROTLI_DECODER_RESULT_SUCCESS) return 4;
    rhash_library_init();
    if (rhash_msg(RHASH_SHA256, "abc", 3, digest) != 0) return 5;
    char hex[65];
    rhash_print_bytes(hex, digest, sizeof(digest), RHPR_HEX);
    if (strcmp(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")) return 6;
    uint8_t *domain = NULL;
    if (idn2_lookup_u8((const uint8_t *)"b\xc3\xbc" "cher.de", &domain, IDN2_NFC_INPUT)) return 7;
    if (!domain || strcmp((const char *)domain, "xn--bcher-kva.de")) return 8;
    idn2_free(domain);
    Tokenizer *tokenizer = tok_init(NULL);
    if (!tokenizer) return 9;
    int argc;
    const char **argv;
    if (tok_str(tokenizer, "alpha 'two words'", &argc, &argv) || argc != 2 ||
        strcmp(argv[0], "alpha") || strcmp(argv[1], "two words")) return 10;
    tok_end(tokenizer);
    puts("Brotli roundtrip/truncation, RHash SHA256, IDNA Unicode, libedit tokens: PASS");
    return 0;
}
