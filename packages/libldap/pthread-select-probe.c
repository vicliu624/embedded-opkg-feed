#include <pthread.h>
#include <stdatomic.h>
#include <sys/select.h>
#include <stdio.h>

static atomic_int ready, run, count;
static void *worker(void *unused)
{
    (void)unused;
    atomic_store(&ready, 1);
    while (!atomic_load(&run)) {}
    while (atomic_load(&run) == 1) atomic_fetch_add(&count, 1);
    return NULL;
}
int main(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, worker, NULL)) return 2;
    while (!atomic_load(&ready)) {}
    struct timeval wait = {0, 100000};
    atomic_store(&run, 1);
    int result = select(0, NULL, NULL, NULL, &wait);
    atomic_store(&run, 2);
    if (pthread_join(thread, NULL) || result != 0) return 3;
    printf("Target pthread makes progress while select waits: %s\n", atomic_load(&count) ? "yes" : "no");
    return atomic_load(&count) ? 0 : 1;
}
