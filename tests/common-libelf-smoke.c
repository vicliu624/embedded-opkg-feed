#include <libelf.h>
#include <gelf.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    assert(argc == 1);
    assert(elf_version(EV_CURRENT) != EV_NONE);
    int fd = open(argv[0], O_RDONLY);
    assert(fd >= 0);
    Elf *object = elf_begin(fd, ELF_C_READ, NULL);
    assert(object && elf_kind(object) == ELF_K_ELF);
    GElf_Ehdr header;
    assert(gelf_getehdr(object, &header));
    assert(header.e_machine == EM_RISCV && header.e_ident[EI_CLASS] == ELFCLASS64);
    size_t sections = 0;
    assert(elf_getshdrnum(object, &sections) == 0 && sections > 0);
    assert(elf_end(object) == 0);
    assert(close(fd) == 0);
    char invalid[] = "not an ELF object";
    object = elf_memory(invalid, sizeof(invalid));
    assert(object && elf_kind(object) == ELF_K_NONE);
    assert(elf_end(object) == 0);
    puts("libelf RISC-V header/section parsing and invalid input: PASS");
    return 0;
}
