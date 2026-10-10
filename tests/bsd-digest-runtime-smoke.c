#include <bsd/string.h>
#include <bsd/stdlib.h>
#include <sha256.h>
#include <string.h>
#include <stdlib.h>

int main(void) {
    char output[SHA256_DIGEST_STRING_LENGTH];
    if (!SHA256Data((const unsigned char *)"abc", 3, output)) return 1;
    if (strcmp(output, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")) return 2;
    char small[4];
    if (strlcpy(small, "abcdef", sizeof small) != 6 || strcmp(small, "abc")) return 3;
    if (strlcat(small, "def", sizeof small) != 6 || strcmp(small, "abc")) return 4;
    const char *error = NULL;
    if (strtonum("42", 0, 100, &error) != 42 || error) return 5;
    strtonum("101", 0, 100, &error);
    if (!error || strcmp(error, "too large")) return 6;
    return 0;
}
