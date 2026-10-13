/* Target-to-target WebSocket exchange over a real local TCP listener. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <libsoup/soup.h>

typedef struct {
    GMainLoop *loop;
    SoupWebsocketConnection *client;
    SoupWebsocketConnection *server_connection;
    unsigned sent_back, received;
    gboolean timed_out;
} State;

static const unsigned char binary[] = {0, 1, 0xff, 0x80, 0};
static const char text[] = "TDVP WebSocket";

static void server_message(SoupWebsocketConnection *connection, gint type, GBytes *bytes, gpointer data)
{
    State *state = data;
    assert(type == SOUP_WEBSOCKET_DATA_TEXT || type == SOUP_WEBSOCKET_DATA_BINARY);
    state->sent_back++;
    soup_websocket_connection_send_message(connection, type, bytes);
}

static void server_connected(SoupServer *server, SoupServerMessage *message, const char *path,
                             SoupWebsocketConnection *connection, gpointer data)
{
    (void)server; (void)message;
    assert(strcmp(path, "/echo") == 0);
    assert(strcmp(soup_websocket_connection_get_protocol(connection), "tdvp-test") == 0);
    ((State *)data)->server_connection = g_object_ref(connection);
    g_signal_connect(connection, "message", G_CALLBACK(server_message), data);
}

static void client_closed(SoupWebsocketConnection *connection, gpointer data)
{
    assert(soup_websocket_connection_get_close_code(connection) == SOUP_WEBSOCKET_CLOSE_NORMAL);
    g_main_loop_quit(((State *)data)->loop);
}

static void client_message(SoupWebsocketConnection *connection, gint type, GBytes *bytes, gpointer data)
{
    State *state = data;
    gsize length;
    const void *payload = g_bytes_get_data(bytes, &length);
    if (state->received == 0) {
        assert(type == SOUP_WEBSOCKET_DATA_TEXT && length == sizeof(text) - 1);
        assert(memcmp(payload, text, length) == 0);
    } else {
        assert(state->received == 1 && type == SOUP_WEBSOCKET_DATA_BINARY && length == sizeof(binary));
        assert(memcmp(payload, binary, length) == 0);
    }
    if (++state->received == 2)
        soup_websocket_connection_close(connection, SOUP_WEBSOCKET_CLOSE_NORMAL, "complete");
}

static void connected(GObject *source, GAsyncResult *result, gpointer data)
{
    State *state = data;
    GError *error = NULL;
    state->client = soup_session_websocket_connect_finish(SOUP_SESSION(source), result, &error);
    assert(!error && state->client);
    assert(strcmp(soup_websocket_connection_get_protocol(state->client), "tdvp-test") == 0);
    g_signal_connect(state->client, "message", G_CALLBACK(client_message), state);
    g_signal_connect(state->client, "closed", G_CALLBACK(client_closed), state);
    soup_websocket_connection_send_text(state->client, text);
    soup_websocket_connection_send_binary(state->client, binary, sizeof(binary));
}

static gboolean timeout(gpointer data)
{
    State *state = data;
    state->timed_out = TRUE;
    g_main_loop_quit(state->loop);
    return G_SOURCE_REMOVE;
}

int main(void)
{
    State state = {0};
    state.loop = g_main_loop_new(NULL, FALSE);
    SoupServer *server = soup_server_new(NULL, NULL);
    char *protocols[] = {"tdvp-test", NULL};
    soup_server_add_websocket_handler(server, "/echo", NULL, protocols, server_connected, &state, NULL);
    GError *error = NULL;
    assert(soup_server_listen_local(server, 0, SOUP_SERVER_LISTEN_IPV4_ONLY, &error) && !error);
    GSList *uris = soup_server_get_uris(server);
    assert(uris);
    int port = g_uri_get_port(uris->data);
    char *url = g_strdup_printf("ws://127.0.0.1:%d/echo", port);
    SoupSession *session = soup_session_new();
    SoupMessage *message = soup_message_new("GET", url);
    soup_session_websocket_connect_async(session, message, NULL, protocols, G_PRIORITY_DEFAULT, NULL, connected, &state);
    guint timer = g_timeout_add_seconds(10, timeout, &state);
    g_main_loop_run(state.loop);
    assert(!state.timed_out && state.received == 2 && state.sent_back == 2);
    g_source_remove(timer);
    soup_server_disconnect(server);
    g_clear_object(&state.client);
    g_clear_object(&state.server_connection);
    g_object_unref(message);
    g_object_unref(session);
    g_object_unref(server);
    g_main_loop_unref(state.loop);
    g_slist_free_full(uris, (GDestroyNotify)g_uri_unref);
    g_free(url);
    puts("libsoup WebSocket: PASS loopback TCP, subprotocol, exact text/binary echoes and normal close");
    return 0;
}
