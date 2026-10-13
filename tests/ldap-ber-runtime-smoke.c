#include <ldap.h>
#include <lber.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    LDAPURLDesc *url = NULL;
    if (ldap_url_parse("ldaps://localhost:636/dc=example,dc=org?cn?sub?(uid=test)", &url) != LDAP_URL_SUCCESS) return 1;
    int valid = url->lud_port == 636 && url->lud_scope == LDAP_SCOPE_SUBTREE && strcmp(url->lud_scheme, "ldaps") == 0;
    ldap_free_urldesc(url);
    if (!valid) return 2;
    LDAPDN dn = NULL;
    if (ldap_str2dn("cn=Test,dc=example,dc=org", &dn, LDAP_DN_FORMAT_LDAPV3) != LDAP_SUCCESS) return 3;
    char *text = NULL;
    if (ldap_dn2str(dn, &text, LDAP_DN_FORMAT_LDAPV3) != LDAP_SUCCESS) { ldap_dnfree(dn); return 4; }
    valid = strcmp(text, "cn=Test,dc=example,dc=org") == 0;
    ldap_memfree(text);
    ldap_dnfree(dn);
    if (!valid) return 5;
    BerElement *encoder = ber_alloc_t(LBER_USE_DER);
    if (!encoder) return 6;
    if (ber_printf(encoder, "{is}", 42, "tdvp") == -1) { ber_free(encoder, 1); return 7; }
    struct berval *data = NULL;
    if (ber_flatten(encoder, &data) != 0) { ber_free(encoder, 1); return 8; }
    BerElement *decoder = ber_init(data);
    ber_int_t number = 0;
    char *string = NULL;
    valid = decoder && ber_scanf(decoder, "{ia}", &number, &string) != LBER_ERROR && number == 42 && string && strcmp(string, "tdvp") == 0;
    if (string) ber_memfree(string);
    if (decoder) ber_free(decoder, 1);
    ber_bvfree(data);
    ber_free(encoder, 1);
    if (!valid) return 9;
    url = NULL;
    if (ldap_url_parse("not-an-ldap-url", &url) == LDAP_URL_SUCCESS) { ldap_free_urldesc(url); return 10; }
    puts("LDAP target LDAPS URL/DN parsing and BER roundtrip, invalid URL rejection: PASS");
    return 0;
}
