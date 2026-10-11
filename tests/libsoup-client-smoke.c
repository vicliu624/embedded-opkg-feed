/* Real HTTP request plus public-suffix API against declared providers. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <libsoup/soup.h>

int main(int argc, char **argv)
{
    assert(argc == 2);
    assert(soup_get_major_version() == 3);
    assert(soup_tld_domain_is_public_suffix("co.uk"));
    GError *error = NULL;
    const char *domain = soup_tld_get_base_domain("www.example.co.uk", &error);
    assert(!error && domain && strcmp(domain, "example.co.uk") == 0);
    SoupSession *session = soup_session_new_with_options("timeout", 10, "user-agent", "TDVP-Feed-Acceptance", NULL);
    SoupMessage *message = soup_message_new("GET", argv[1]);
    assert(session && message);
    GBytes *body = soup_session_send_and_read(session, message, NULL, &error);
    if (error) {
        fprintf(stderr, "libsoup request failed: %s\n", error->message);
        return 1;
    }
    assert(body && soup_message_get_status(message) == SOUP_STATUS_OK);
    gsize length = 0;
    const char *bytes = g_bytes_get_data(body, &length);
    const char expected[] = "tdvp-libsoup-loopback\n";
    assert(length == sizeof(expected) - 1 && memcmp(bytes, expected, length) == 0);
    g_bytes_unref(body);
    g_object_unref(message);
    g_object_unref(session);
    puts("libsoup client: PASS real HTTP body, status and public-suffix provider");
    return 0;
}
