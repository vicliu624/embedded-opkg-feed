#include <libaio.h>
#include <liburing.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char path[] = "tdvp-kernel-io-XXXXXX";
    const char expected[] = "TDVP kernel async I/O";
    char buffer[sizeof(expected)];
    int fd = mkstemp(path), status = 0;
    io_context_t aio = 0;
    struct io_uring ring;
    int ring_ready = 0;
    if (fd < 0) return 1;
    if (write(fd, expected, sizeof(expected)) != sizeof(expected)) { status = 2; goto done; }
    int result = io_setup(2, &aio);
    if (result) { fprintf(stderr, "io_setup: %d\n", result); status = 3; goto done; }
    struct iocb request;
    struct iocb *requests[] = { &request };
    io_prep_pread(&request, fd, buffer, sizeof(buffer), 0);
    if (io_submit(aio, 1, requests) != 1) { status = 4; goto done; }
    struct io_event event;
    struct timespec timeout = { 2, 0 };
    if (io_getevents(aio, 1, 1, &event, &timeout) != 1 || event.res != sizeof(expected) || event.res2 || memcmp(buffer, expected, sizeof(expected))) { status = 5; goto done; }
    result = io_uring_queue_init(2, &ring, 0);
    if (result) { fprintf(stderr, "io_uring_queue_init: %d\n", result); status = 6; goto done; }
    ring_ready = 1;
    struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
    if (!sqe) { status = 7; goto done; }
    memset(buffer, 0, sizeof(buffer));
    io_uring_prep_read(sqe, fd, buffer, sizeof(buffer), 0);
    if (io_uring_submit(&ring) != 1) { status = 8; goto done; }
    struct io_uring_cqe *cqe;
    struct __kernel_timespec ring_timeout = { 2, 0 };
    result = io_uring_wait_cqe_timeout(&ring, &cqe, &ring_timeout);
    if (result || cqe->res != sizeof(expected) || memcmp(buffer, expected, sizeof(expected))) { status = 9; goto done; }
    io_uring_cqe_seen(&ring, cqe);
    puts("Kernel AIO and io_uring bounded temporary-file readback: PASS");
done:
    if (ring_ready) io_uring_queue_exit(&ring);
    if (aio) io_destroy(aio);
    close(fd);
    unlink(path);
    return status;
}
