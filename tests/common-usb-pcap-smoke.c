#include <libusb.h>
#include <pcap/pcap.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const struct libusb_version *version = libusb_get_version();
    if (!version || version->major != 1 || version->micro != 27) return 1;
    libusb_context *context = NULL;
    if (libusb_init(&context) != 0) return 2;
    libusb_device **devices = NULL;
    ssize_t count = libusb_get_device_list(context, &devices);
    if (count < 0) return 3;
    libusb_free_device_list(devices, 1);
    libusb_exit(context);

    pcap_t *capture = pcap_open_dead(DLT_EN10MB, 65535);
    struct bpf_program filter;
    if (!capture || pcap_compile(capture, &filter, "udp and dst port 53", 1, PCAP_NETMASK_UNKNOWN) != 0) return 4;
    unsigned char packet[42] = {0};
    packet[12] = 8;
    packet[14] = 0x45;
    packet[17] = 28;
    packet[23] = 17;
    packet[37] = 53;
    packet[39] = 8;
    struct pcap_pkthdr header = {0};
    header.caplen = header.len = sizeof(packet);
    if (!pcap_offline_filter(&filter, &header, packet)) return 5;
    packet[37] = 80;
    if (pcap_offline_filter(&filter, &header, packet)) return 6;
    pcap_freecode(&filter);
    pcap_close(capture);
    puts("libusb initialization/enumeration and libpcap offline BPF positive/negative filters: PASS");
    return 0;
}
