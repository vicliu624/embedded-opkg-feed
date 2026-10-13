#include <H5Cpp.h>
#include <hdf5_hl.h>
#include <array>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

int main()
{
    static_assert(sizeof(unsigned short) == 2);
    std::array<unsigned short, 64> original{}, decoded{};
    for (unsigned int i = 0; i < original.size(); ++i) original[i] = 1000 + i * i;
    char filename[] = "tdvp-hdf5-XXXXXX";
    int fd = mkstemp(filename);
    if (fd < 0) return 1;
    close(fd);
    hid_t file = H5Fcreate(filename, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    if (file < 0) return 2;
    hsize_t dimension = original.size(), chunk = 32;
    hid_t space = H5Screate_simple(1, &dimension, nullptr);
    if (space < 0) return 3;
    for (int kind = 0; kind < 2; ++kind) {
        H5Z_filter_t filter = kind ? H5Z_FILTER_SZIP : H5Z_FILTER_DEFLATE;
        unsigned int capabilities = 0;
        if (H5Zfilter_avail(filter) <= 0 || H5Zget_filter_info(filter, &capabilities) < 0 ||
            (capabilities & (H5Z_FILTER_CONFIG_ENCODE_ENABLED | H5Z_FILTER_CONFIG_DECODE_ENABLED)) !=
             (H5Z_FILTER_CONFIG_ENCODE_ENABLED | H5Z_FILTER_CONFIG_DECODE_ENABLED)) return 4;
        hid_t properties = H5Pcreate(H5P_DATASET_CREATE);
        if (properties < 0 || H5Pset_chunk(properties, 1, &chunk) < 0) return 5;
        if ((kind ? H5Pset_szip(properties, H5_SZIP_NN_OPTION_MASK, 8) : H5Pset_deflate(properties, 6)) < 0) return 6;
        const char *name = kind ? "szip" : "deflate";
        hid_t dataset = H5Dcreate2(file, name, H5T_NATIVE_USHORT, space, H5P_DEFAULT, properties, H5P_DEFAULT);
        if (dataset < 0 || H5Dwrite(dataset, H5T_NATIVE_USHORT, H5S_ALL, H5S_ALL, H5P_DEFAULT, original.data()) < 0) return 7;
        if (H5Dclose(dataset) < 0 || H5Pclose(properties) < 0) return 8;
    }
    int high_level[] = {3, 5, 8, 13};
    hsize_t high_dimension = 4;
    if (H5LTmake_dataset_int(file, "high-level", 1, &high_dimension, high_level) < 0) return 9;
    if (H5Sclose(space) < 0 || H5Fclose(file) < 0) return 10;
    try {
        H5::H5File reader(filename, H5F_ACC_RDONLY);
        for (const char *name : {"deflate", "szip"}) {
            H5::DataSet dataset = reader.openDataSet(name);
            dataset.read(decoded.data(), H5::PredType::NATIVE_USHORT);
            if (decoded != original) return 11;
        }
        int high_decoded[4] = {};
        if (H5LTread_dataset_int(reader.getId(), "high-level", high_decoded) < 0) return 12;
        for (int i = 0; i < 4; ++i) if (high_decoded[i] != high_level[i]) return 13;
    } catch (const H5::Exception &error) {
        error.printErrorStack();
        return 14;
    }
    if (unlink(filename)) return 15;
    std::puts("HDF5 target C/C++/HL, deflate and SZIP encoded datasets reopened with exact values: PASS");
    return 0;
}
