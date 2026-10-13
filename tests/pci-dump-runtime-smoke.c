#define _GNU_SOURCE
#include <pci/pci.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
    char filename[] = "tdvp-pci-dump-XXXXXX";
    int fd = mkstemp(filename);
    if (fd < 0) return 1;
    FILE *output = fdopen(fd, "w");
    if (!output) { close(fd); unlink(filename); return 2; }
    if (fputs("0000:00:01.0 Synthetic fixture\n00: 34 12 78 56 00 00 00 00 00 00 00 00 00 00 00 00\n\n", output) < 0 || fclose(output)) {
        unlink(filename); return 3;
    }
    struct pci_access *access = pci_alloc();
    if (!access) { unlink(filename); return 4; }
    access->method = PCI_ACCESS_DUMP;
    if (pci_set_param(access, "dump.name", filename)) return 5;
    pci_init(access);
    pci_scan_bus(access);
    struct pci_dev *device = access->devices;
    if (!device || device->next) return 6;
    pci_fill_info(device, PCI_FILL_IDENT);
    if (device->vendor_id != 0x1234 || device->device_id != 0x5678) return 7;
    struct pci_filter filter;
    pci_filter_init(access, &filter);
    char slot[] = "0000:00:01.0";
    char id[] = "1234:5678";
    char invalid[] = "zzzz:5678";
    if (pci_filter_parse_slot(&filter, slot) || pci_filter_parse_id(&filter, id)) return 8;
    if (!pci_filter_match(&filter, device)) return 9;
    filter.device = 0x9999;
    if (pci_filter_match(&filter, device)) return 10;
    if (!pci_filter_parse_id(&filter, invalid)) return 11;
    pci_cleanup(access);
    if (unlink(filename)) return 12;
    puts("PCI dump backend, identity, positive/negative filters and invalid input: PASS");
    return 0;
}
