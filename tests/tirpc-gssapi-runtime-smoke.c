#include <rpc/rpc.h>
#include <rpc/rpcsec_gss.h>
#include <string.h>

int main(void) {
    char bytes[128];
    XDR stream;
    unsigned value = 42;
    char *text = "TDVP-XDR";
    xdrmem_create(&stream, bytes, sizeof bytes, XDR_ENCODE);
    if (!xdr_u_int(&stream, &value) || !xdr_string(&stream, &text, 32)) return 1;
    unsigned length = xdr_getpos(&stream);
    xdr_destroy(&stream);
    value = 0;
    text = NULL;
    xdrmem_create(&stream, bytes, length, XDR_DECODE);
    if (!xdr_u_int(&stream, &value) || !xdr_string(&stream, &text, 32)) return 2;
    int status = value == 42 && !strcmp(text, "TDVP-XDR") ? 0 : 3;
    xdr_destroy(&stream);
    xdr_free((xdrproc_t)xdr_wrapstring, (char *)&text);
    if (status) return status;
    char **mechanisms = rpc_gss_get_mechanisms();
    if (!mechanisms) return 4;
    for (int i = 0; mechanisms[i]; ++i)
        if (!strcmp(mechanisms[i], "kerberos_v5")) return 0;
    return 5;
}
