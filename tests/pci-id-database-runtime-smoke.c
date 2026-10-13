#include <pci/pci.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc != 2) return 1;
    struct pci_access *access = pci_alloc();
    if (!access) return 2;
    char output[256];
    /* Read only the supplied locked ID database; do not initialise hardware. */
    pci_set_name_list_path(access, argv[1], 0);
    char *name = pci_lookup_name(access, output, sizeof(output), PCI_LOOKUP_VENDOR, 0x8086);
    int result = !name || strcmp(name, "Intel Corporation");
    pci_cleanup(access);
    if (result) return 3;
    puts("PCI compressed identifier database vendor lookup: PASS");
    return 0;
}
