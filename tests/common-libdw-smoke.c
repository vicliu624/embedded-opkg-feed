#include <elfutils/libdw.h>
#include <dwarf.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    assert(argc == 1);
    int fd = open(argv[0], O_RDONLY);
    assert(fd >= 0);
    Dwarf *object = dwarf_begin(fd, DWARF_C_READ);
    assert(object != NULL);
    Dwarf_Off next;
    size_t header_size;
    assert(dwarf_nextcu(object, 0, &next, &header_size, NULL, NULL, NULL) == 0);
    Dwarf_Die die;
    assert(dwarf_offdie(object, header_size, &die) != NULL);
    assert(dwarf_tag(&die) == DW_TAG_compile_unit);
    const char *name = dwarf_diename(&die);
    assert(name && strstr(name, "common-libdw-smoke.c"));
    assert(dwarf_end(object) == 0);
    assert(close(fd) == 0);
    puts("libdw DWARF compilation unit and source-name parsing: PASS");
    return 0;
}
