#include <gudev/gudev.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    GUdevClient *client = g_udev_client_new(NULL);
    if (!client) return 1;
    /* /sys/class/mem/null is supplied by the validation host's sysfs. */
    GUdevDevice *device = g_udev_client_query_by_sysfs_path(client, "/sys/class/mem/null");
    if (!device) return 2;
    const char *name = g_udev_device_get_name(device);
    const char *subsystem = g_udev_device_get_subsystem(device);
    if (!name || strcmp(name, "null") || !subsystem || strcmp(subsystem, "mem")) return 3;
    if (!g_udev_device_get_sysfs_path(device)) return 4;
    g_object_unref(device);
    g_object_unref(client);
    puts("GUdev client: PASS actual sysfs lookup, name, subsystem and object lifecycle");
    return 0;
}
