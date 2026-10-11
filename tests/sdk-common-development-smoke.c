#include <curses.h>
#include <curl/curl.h>
#include <openssl/crypto.h>
#include <zlib.h>
#include <png.h>
#include <sndfile.h>
#include <stdio.h>

/* No terminal, network, or sound device required: exercise SDK-linked APIs. */
int main(void) {
    if (!curses_version() || !curl_version() || !OpenSSL_version(OPENSSL_VERSION) ||
        !zlibVersion() || !png_get_libpng_ver(NULL) || !sf_version_string()) return 1;
    if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) return 2;
    CURL *client = curl_easy_init();
    if (!client) return 3;
    curl_easy_cleanup(client);
    curl_global_cleanup();
    puts("SDK common development compile/link/runtime: PASS ncurses curl OpenSSL zlib PNG sndfile");
    return 0;
}
