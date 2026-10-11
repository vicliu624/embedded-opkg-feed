#include <sasl/sasl.h>
#include <sasl/saslutil.h>
#include <stdio.h>
#include <string.h>

static int plugin_path(void *context, const char **path)
{
    *path = context;
    return SASL_OK;
}

int main(int argc, char **argv)
{
    if (argc != 2) return 64;
    sasl_callback_t callbacks[] = {
        {SASL_CB_GETPATH, (int (*)(void))plugin_path, argv[1]},
        {SASL_CB_LIST_END, NULL, NULL}
    };
    if (sasl_client_init(callbacks) != SASL_OK) return 1;
    const char **mechanisms = sasl_global_listmech();
    int scram = 0, gssapi = 0, plain = 0;
    for (int i = 0; mechanisms && mechanisms[i]; ++i) {
        scram |= strcmp(mechanisms[i], "SCRAM-SHA-256") == 0;
        gssapi |= strcmp(mechanisms[i], "GSSAPI") == 0;
        plain |= strcmp(mechanisms[i], "PLAIN") == 0;
    }
    if (!scram || !gssapi || !plain) { sasl_done(); return 2; }
    char encoded[32], decoded[32];
    unsigned encoded_size = 0, decoded_size = 0;
    if (sasl_encode64("tdvp", 4, encoded, sizeof(encoded), &encoded_size) != SASL_OK ||
        sasl_decode64(encoded, encoded_size, decoded, sizeof(decoded), &decoded_size) != SASL_OK ||
        decoded_size != 4 || memcmp(decoded, "tdvp", 4)) { sasl_done(); return 3; }
    sasl_done();
    puts("SASL target SCRAM-SHA-256/GSSAPI/PLAIN plugin loading and base64 roundtrip: PASS");
    return 0;
}
