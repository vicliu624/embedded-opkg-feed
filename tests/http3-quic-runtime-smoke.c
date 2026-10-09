#include <nghttp3/nghttp3.h>
#include <ngtcp2/ngtcp2.h>
#include <ngtcp2/ngtcp2_crypto_gnutls.h>
#include <gnutls/gnutls.h>
#include <string.h>

int main(void) {
    const nghttp3_info *http = nghttp3_version(0);
    const ngtcp2_info *quic = ngtcp2_version(0);
    if (!http || strcmp(http->version_str, "1.18.0")) return 1;
    if (!quic || strcmp(quic->version_str, "1.25.0")) return 2;
    nghttp3_settings settings;
    nghttp3_settings_default(&settings);
    nghttp3_callbacks callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    nghttp3_conn *client = NULL;
    if (nghttp3_conn_client_new(&client, &callbacks, &settings, NULL, NULL)) return 3;
    if (!client) return 4;
    nghttp3_conn_del(client);
    if (!ngtcp2_is_bidi_stream(0) || ngtcp2_is_bidi_stream(2)) return 5;
    if (gnutls_global_init()) return 6;
    gnutls_session_t tls;
    if (gnutls_init(&tls, GNUTLS_CLIENT)) return 7;
    if (gnutls_priority_set_direct(tls, "NORMAL:-VERS-ALL:+VERS-TLS1.3", NULL)) return 8;
    if (ngtcp2_crypto_gnutls_configure_client_session(tls)) return 9;
    gnutls_deinit(tls);
    gnutls_global_deinit();
    return 0;
}
