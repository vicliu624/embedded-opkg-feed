#include <ares.h>
#include <nghttp2/nghttp2.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    ares_channel channel;
    assert(ares_library_init(ARES_LIB_INIT_ALL) == ARES_SUCCESS);
    assert(strcmp(ares_version(NULL), "1.34.8") == 0);
    assert(ares_init(&channel) == ARES_SUCCESS);
    ares_destroy(channel);
    ares_library_cleanup();

    const nghttp2_info *info = nghttp2_version(0);
    assert(info && strcmp(info->version_str, "1.70.0") == 0);
    nghttp2_session_callbacks *callbacks = NULL;
    nghttp2_session *session = NULL;
    assert(nghttp2_session_callbacks_new(&callbacks) == 0);
    assert(nghttp2_session_client_new(&session, callbacks, NULL) == 0);
    nghttp2_settings_entry setting = {NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS, 10};
    assert(nghttp2_submit_settings(session, NGHTTP2_FLAG_NONE, &setting, 1) == 0);
    const unsigned char *wire = NULL;
    assert(nghttp2_session_mem_send(session, &wire) > 0);
    assert(wire != NULL);
    nghttp2_session_del(session);
    nghttp2_session_callbacks_del(callbacks);
    puts("c-ares initialization and nghttp2 client framing: PASS");
    return 0;
}
