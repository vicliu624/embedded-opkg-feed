#define UNW_LOCAL_ONLY
#include <libunwind.h>
#include <stdio.h>

__attribute__((noinline)) static int inspect_stack(void) {
    unw_context_t context;
    unw_cursor_t cursor;
    unw_word_t ip;
    if (unw_getcontext(&context) < 0) return 1;
    if (unw_init_local(&cursor, &context) < 0) return 2;
    if (unw_get_reg(&cursor, UNW_REG_IP, &ip) < 0 || !ip) return 3;
    int frames = 1;
    int step;
    while ((step = unw_step(&cursor)) > 0 && frames < 64) {
        if (unw_get_reg(&cursor, UNW_REG_IP, &ip) < 0 || !ip) return 4;
        ++frames;
    }
    if (step < 0 || frames < 2 || frames == 64) return 5;
    printf("libunwind local stack: %d frames\n", frames);
    return 0;
}

int main(void) { return inspect_stack(); }
