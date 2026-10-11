#include <stdio.h>
#include <string.h>
int main(void) {
    char output[32];
    int length = snprintf(output, sizeof output, "%2$s:%1$d", 42, "TDVP");
    return length == 7 && strcmp(output, "TDVP:42") == 0 ? 0 : 1;
}
