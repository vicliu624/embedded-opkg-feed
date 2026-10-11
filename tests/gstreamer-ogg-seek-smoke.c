#include <assert.h>
#include <stdio.h>
#include <gst/gst.h>

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    assert(argc == 2);
    GError *error = NULL;
    GstElement *writer = gst_parse_launch(
        "videotestsrc num-buffers=45 ! video/x-raw,format=I420,width=64,height=64 ! theoraenc ! oggmux ! filesink name=file", &error);
    assert(writer && !error);
    GstElement *file = gst_bin_get_by_name(GST_BIN(writer), "file");
    assert(file);
    g_object_set(file, "location", argv[1], NULL);
    gst_object_unref(file);
    assert(gst_element_set_state(writer, GST_STATE_PLAYING) != GST_STATE_CHANGE_FAILURE);
    GstBus *bus = gst_element_get_bus(writer);
    GstMessage *message = gst_bus_timed_pop_filtered(bus, 20 * GST_SECOND, GST_MESSAGE_EOS | GST_MESSAGE_ERROR);
    assert(message && GST_MESSAGE_TYPE(message) == GST_MESSAGE_EOS);
    gst_message_unref(message);
    gst_object_unref(bus);
    gst_element_set_state(writer, GST_STATE_NULL);
    gst_object_unref(writer);

    GstElement *reader = gst_parse_launch(
        "filesrc name=file ! oggdemux ! theoradec ! fakesink sync=false", &error);
    assert(reader && !error);
    file = gst_bin_get_by_name(GST_BIN(reader), "file");
    assert(file);
    g_object_set(file, "location", argv[1], NULL);
    gst_object_unref(file);
    assert(gst_element_set_state(reader, GST_STATE_PAUSED) != GST_STATE_CHANGE_FAILURE);
    assert(gst_element_get_state(reader, NULL, NULL, 10 * GST_SECOND) == GST_STATE_CHANGE_SUCCESS);
    gint64 duration = 0;
    assert(gst_element_query_duration(reader, GST_FORMAT_TIME, &duration));
    assert(duration >= GST_SECOND);
    GstEvent *seek = gst_event_new_seek(1.0, GST_FORMAT_TIME,
        GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE,
        GST_SEEK_TYPE_SET, GST_SECOND / 2, GST_SEEK_TYPE_NONE, -1);
    assert(seek);
    gst_event_set_seqnum(seek, gst_util_seqnum_next());
    assert(gst_element_send_event(reader, seek));
    assert(gst_element_set_state(reader, GST_STATE_PLAYING) != GST_STATE_CHANGE_FAILURE);
    bus = gst_element_get_bus(reader);
    message = gst_bus_timed_pop_filtered(bus, 20 * GST_SECOND, GST_MESSAGE_EOS | GST_MESSAGE_ERROR);
    assert(message && GST_MESSAGE_TYPE(message) == GST_MESSAGE_EOS);
    gst_message_unref(message);
    gst_object_unref(bus);
    gst_element_set_state(reader, GST_STATE_NULL);
    gst_object_unref(reader);
    gst_deinit();
    puts("GStreamer Ogg: PASS file generation, duration, accurate flushing seek and EOS");
    return 0;
}
