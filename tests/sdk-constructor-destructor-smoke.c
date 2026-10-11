#include <stdlib.h>
static int state;
__attribute__((constructor)) static void initialize(void) { state = 1; }
__attribute__((destructor)) static void finish(void) { if (state != 2) abort(); }
int main(void) {
    if (state != 1) return 1;
    state = 2;
    return 0;
}
