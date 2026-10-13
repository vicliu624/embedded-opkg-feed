#include <libaio.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    struct iocb request;
    char buffer[32];
    memset(&request, 0xff, sizeof(request));
    io_prep_pread(&request, 7, buffer, sizeof(buffer), 123);
    if (request.aio_lio_opcode != IO_CMD_PREAD || request.aio_fildes != 7 ||
        request.u.c.buf != buffer || request.u.c.nbytes != sizeof(buffer) || request.u.c.offset != 123) return 1;
    io_prep_pwrite(&request, 8, buffer, sizeof(buffer), 456);
    if (request.aio_lio_opcode != IO_CMD_PWRITE || request.aio_fildes != 8 || request.u.c.offset != 456) return 2;
    io_context_t context = 0;
    int status = io_setup(0, &context);
    if (status == -ENOSYS) puts("Kernel AIO probe unavailable under QEMU; real device check remains required");
    else if (status != -EINVAL) return 3;
    puts("libaio request preparation and negative syscall result: PASS");
    return 0;
}
