#include <liburing.h>
#include <string.h>

int main(void) {
    if (io_uring_major_version() != 2 || io_uring_minor_version() != 15) return 1;
    struct io_uring_sqe sqe;
    memset(&sqe, 0xff, sizeof(sqe));
    io_uring_prep_nop(&sqe);
    if (sqe.opcode != IORING_OP_NOP || sqe.fd != -1 || sqe.len != 0) return 2;
    io_uring_sqe_set_data64(&sqe, 0x12345678);
    if (sqe.user_data != 0x12345678) return 3;
    char buffer[32];
    io_uring_prep_read(&sqe, 7, buffer, sizeof(buffer), 123);
    if (sqe.opcode != IORING_OP_READ || sqe.fd != 7 || sqe.len != sizeof(buffer) || sqe.off != 123 || sqe.addr != (unsigned long)buffer) return 4;
    io_uring_prep_write(&sqe, 8, buffer, sizeof(buffer), 456);
    if (sqe.opcode != IORING_OP_WRITE || sqe.fd != 8 || sqe.off != 456) return 5;
    return 0;
}
