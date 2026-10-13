#include <H5PacketTable.h>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

int main()
{
    char filename[] = "tdvp-hdf5-packets-XXXXXX";
    int fd = mkstemp(filename);
    if (fd < 0) return 1;
    close(fd);
    hid_t file = H5Fcreate(filename, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    if (file < 0) return 2;
    int input[] = {21, 34, 55};
    {
        const char *name = "packets";
        FL_PacketTable table(file, name, H5T_NATIVE_INT, hsize_t{16}, hid_t{H5P_DEFAULT});
        if (!table.IsValid() || table.AppendPackets(3, input) < 0) return 3;
        int error = 0;
        if (table.GetPacketCount(error) != 3 || error < 0) return 4;
    }
    if (H5Fclose(file) < 0) return 5;
    file = H5Fopen(filename, H5F_ACC_RDONLY, H5P_DEFAULT);
    if (file < 0) return 6;
    {
        FL_PacketTable table(file, "packets");
        if (!table.IsValid()) return 7;
        for (hsize_t i = 0; i < 3; ++i) {
            int value = 0;
            if (table.GetPacket(i, &value) < 0 || value != input[i]) return 8;
        }
    }
    if (H5Fclose(file) < 0 || unlink(filename)) return 9;
    std::puts("HDF5 high-level C++ packet table append/count/close/reopen/read: PASS");
    return 0;
}
