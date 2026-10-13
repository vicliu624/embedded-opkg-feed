#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <gst/gst.h>
#include <gst/app/gstappsrc.h>
#include <gst/app/gstappsink.h>

int main(int argc, char **argv)
{
    const unsigned char expected[] = {0, 1, 39, 92, 127, 255, 17, 33};
    GError *error = NULL;
    gst_init(&argc, &argv);
    GstElement *pipeline = gst_parse_launch(
        "appsrc name=input caps=application/octet-stream ! identity ! appsink name=output sync=false", &error);
    assert(pipeline && !error);
    GstElement *input = gst_bin_get_by_name(GST_BIN(pipeline), "input");
    GstElement *output = gst_bin_get_by_name(GST_BIN(pipeline), "output");
    assert(input && output);
    assert(gst_element_set_state(pipeline, GST_STATE_PLAYING) != GST_STATE_CHANGE_FAILURE);
    GstBuffer *buffer = gst_buffer_new_allocate(NULL, sizeof(expected), NULL);
    assert(buffer && gst_buffer_fill(buffer, 0, expected, sizeof(expected)) == sizeof(expected));
    GST_BUFFER_PTS(buffer) = 0;
    GST_BUFFER_DURATION(buffer) = GST_MSECOND;
    assert(gst_app_src_push_buffer(GST_APP_SRC(input), buffer) == GST_FLOW_OK);
    assert(gst_app_src_end_of_stream(GST_APP_SRC(input)) == GST_FLOW_OK);
    GstSample *sample = gst_app_sink_try_pull_sample(GST_APP_SINK(output), 10 * GST_SECOND);
    assert(sample);
    GstMapInfo map;
    GstBuffer *received = gst_sample_get_buffer(sample);
    assert(received && gst_buffer_map(received, &map, GST_MAP_READ));
    assert(map.size == sizeof(expected) && memcmp(map.data, expected, sizeof(expected)) == 0);
    gst_buffer_unmap(received, &map);
    gst_sample_unref(sample);
    assert(gst_app_sink_try_pull_sample(GST_APP_SINK(output), 10 * GST_SECOND) == NULL);
    assert(gst_app_sink_is_eos(GST_APP_SINK(output)));
    buffer = gst_buffer_new_allocate(NULL, 1, NULL);
    assert(buffer);
    assert(gst_app_src_push_buffer(GST_APP_SRC(input), buffer) == GST_FLOW_EOS);
    GstBus *bus = gst_element_get_bus(pipeline);
    GstMessage *message = gst_bus_timed_pop_filtered(bus, 10 * GST_SECOND, GST_MESSAGE_EOS | GST_MESSAGE_ERROR);
    assert(message && GST_MESSAGE_TYPE(message) == GST_MESSAGE_EOS);
    gst_message_unref(message);
    gst_object_unref(bus);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(input);
    gst_object_unref(output);
    gst_object_unref(pipeline);
    gst_deinit();
    puts("GStreamer app buffers: PASS exact binary roundtrip, EOS and post-EOS rejection");
    return 0;
}
