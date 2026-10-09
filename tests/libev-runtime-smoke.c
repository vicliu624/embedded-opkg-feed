#include <ev.h>
#include <stdio.h>
static int fired;
static void timer_ready(EV_P_ ev_timer *watcher, int events) {
    if (events & EV_TIMER) ++fired;
    ev_timer_stop(EV_A_ watcher);
    ev_break(EV_A_ EVBREAK_ALL);
}
int main(void) {
    struct ev_loop *loop = ev_loop_new(EVFLAG_AUTO);
    if (!loop) return 1;
    ev_timer timer;
    ev_timer_init(&timer, timer_ready, 0.01, 0.0);
    ev_timer_start(loop, &timer);
    ev_run(loop, 0);
    ev_loop_destroy(loop);
    if (fired != 1) return 2;
    puts("libev real timer dispatch and loop teardown: PASS");
    return 0;
}
