#include <numa.h>
#include <stdio.h>

int main(void)
{
    struct bitmask *first = numa_bitmask_alloc(130);
    struct bitmask *second = numa_bitmask_alloc(130);
    if (!first || !second) return 1;
    numa_bitmask_clearall(first);
    numa_bitmask_clearall(second);
    numa_bitmask_setbit(first, 0);
    numa_bitmask_setbit(first, 64);
    numa_bitmask_setbit(first, 129);
    if (numa_bitmask_weight(first) != 3 || !numa_bitmask_isbitset(first, 129) ||
        numa_bitmask_isbitset(first, 128)) return 2;
    if (numa_bitmask_equal(first, second)) return 3;
    numa_bitmask_setbit(second, 0);
    numa_bitmask_setbit(second, 64);
    numa_bitmask_setbit(second, 129);
    if (!numa_bitmask_equal(first, second)) return 4;
    numa_bitmask_clearbit(first, 64);
    if (numa_bitmask_weight(first) != 2 || numa_bitmask_isbitset(first, 64)) return 5;
    numa_bitmask_free(first);
    numa_bitmask_free(second);
    /* Capability query only. No mbind, allocation policy or CPU affinity writes. */
    int available = numa_available();
    if (available != 0 && available != -1) return 6;
    printf("libnuma multiword bitmask APIs: PASS; numa_available=%d (capability report, not NUMA hardware acceptance)\n", available);
    return 0;
}
