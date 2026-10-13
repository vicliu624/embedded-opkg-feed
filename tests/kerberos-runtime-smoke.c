#include <krb5.h>
#include <gssapi/gssapi.h>
#include <string.h>

int main(void) {
    krb5_context context;
    krb5_principal principal;
    if (krb5_init_context(&context)) return 1;
    if (krb5_parse_name(context, "tdvp@TDVP.TEST", &principal)) {
        krb5_free_context(context);
        return 2;
    }
    const krb5_data *realm = krb5_princ_realm(context, principal);
    int status = realm->length == 9 && !memcmp(realm->data, "TDVP.TEST", 9) ? 0 : 3;
    krb5_free_principal(context, principal);
    krb5_free_context(context);
    if (status) return status;
    OM_uint32 minor;
    gss_name_t name = GSS_C_NO_NAME;
    gss_buffer_desc text = {4, "tdvp"};
    if (gss_import_name(&minor, &text, GSS_C_NT_USER_NAME, &name) != GSS_S_COMPLETE) return 4;
    gss_buffer_desc displayed = GSS_C_EMPTY_BUFFER;
    if (gss_display_name(&minor, name, &displayed, NULL) != GSS_S_COMPLETE) {
        gss_release_name(&minor, &name);
        return 5;
    }
    status = displayed.length == 4 && !memcmp(displayed.value, "tdvp", 4) ? 0 : 6;
    gss_release_buffer(&minor, &displayed);
    gss_release_name(&minor, &name);
    return status;
}
