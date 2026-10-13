#include <libserialport.h>
#include <stdio.h>
int main(void) {
    struct sp_port_config *configuration = NULL;
    if (sp_new_config(&configuration) != SP_OK) return 1;
    if (sp_set_config_baudrate(configuration, 115200) != SP_OK ||
        sp_set_config_bits(configuration, 8) != SP_OK ||
        sp_set_config_parity(configuration, SP_PARITY_NONE) != SP_OK ||
        sp_set_config_stopbits(configuration, 1) != SP_OK) return 2;
    int rate = 0, bits = 0, stops = 0;
    enum sp_parity parity = SP_PARITY_INVALID;
    if (sp_get_config_baudrate(configuration, &rate) != SP_OK || rate != 115200 ||
        sp_get_config_bits(configuration, &bits) != SP_OK || bits != 8 ||
        sp_get_config_parity(configuration, &parity) != SP_OK || parity != SP_PARITY_NONE ||
        sp_get_config_stopbits(configuration, &stops) != SP_OK || stops != 1) return 3;
    sp_free_config(configuration);
    puts("libserialport configuration object roundtrip: PASS; no port opened or hardware changed");
    return 0;
}
