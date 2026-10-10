#include <talloc.h>
#include <tevent.h>
#include <string.h>

static int destroyed;
static int destroy_child(char *value) { (void)value; ++destroyed; return 0; }
static void timer_handler(struct tevent_context *context, struct tevent_timer *timer,
                          struct timeval now, void *data) {
    (void)context; (void)timer; (void)now;
    *(int *)data = 1;
}
int main(void) {
    void *root = talloc_new(NULL);
    if (!root) return 1;
    char *child = talloc_strdup(root, "TDVP-tree");
    if (!child || strcmp(child, "TDVP-tree")) { talloc_free(root); return 2; }
    talloc_set_destructor(child, destroy_child);
    struct tevent_context *events = tevent_context_init(root);
    int fired = 0;
    if (!events || !tevent_add_timer(events, events, tevent_timeval_current_ofs(0, 1000), timer_handler, &fired)) {
        talloc_free(root); return 3;
    }
    if (tevent_loop_once(events) || !fired) { talloc_free(root); return 4; }
    if (talloc_free(root) || destroyed != 1) return 5;
    return 0;
}
