#include <gssapi/gssapi.h>
#include <stdio.h>

int main(void)
{
    OM_uint32 minor = 0;
    gss_OID_desc spnego = {6, (void *) "\x2b\x06\x01\x05\x05\x02"};
    gss_OID_set mechanisms = GSS_C_NO_OID_SET;
    int present = 0;
    if (gss_indicate_mechs(&minor, &mechanisms) != GSS_S_COMPLETE) return 2;
    OM_uint32 result = gss_test_oid_set_member(&minor, &spnego, mechanisms, &present);
    gss_release_oid_set(&minor, &mechanisms);
    if (result != GSS_S_COMPLETE) return 3;
    printf("Target GSSAPI SPNEGO mechanism available: %s\n", present ? "yes" : "no");
    return present ? 0 : 1;
}
