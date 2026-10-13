#include <netcdf.h>
#include <stdio.h>
#include <string.h>

#define CHECK(call) do { int status = (call); if (status != NC_NOERR) { fprintf(stderr, "%s: %s\n", #call, nc_strerror(status)); return 1; } } while (0)

int main(int argc, char **argv) {
    if (argc != 3) return 64;
    int mode = strcmp(argv[1], "cdf5") == 0 ? NC_64BIT_DATA : NC_NETCDF4;
    int file, dimension, variable;
    CHECK(nc_create(argv[2], mode | NC_CLOBBER, &file));
    CHECK(nc_def_dim(file, "sample", 4, &dimension));
    CHECK(nc_def_var(file, "values", NC_DOUBLE, 1, &dimension, &variable));
    if (strcmp(argv[1], "hdf5") == 0) CHECK(nc_def_var_deflate(file, variable, 1, 1, 4));
    const char title[] = "TDVP dataset";
    CHECK(nc_put_att_text(file, NC_GLOBAL, "title", sizeof(title) - 1, title));
    CHECK(nc_enddef(file));
    double expected[] = {1.25, -2.5, 0, 1024.125};
    CHECK(nc_put_var_double(file, variable, expected));
    CHECK(nc_close(file));
    CHECK(nc_open(argv[2], NC_NOWRITE, &file));
    CHECK(nc_inq_varid(file, "values", &variable));
    double actual[4];
    CHECK(nc_get_var_double(file, variable, actual));
    if (memcmp(actual, expected, sizeof(actual))) return 2;
    char text[sizeof(title)] = {0};
    CHECK(nc_get_att_text(file, NC_GLOBAL, "title", text));
    if (strcmp(text, title)) return 3;
    CHECK(nc_close(file));
    printf("NetCDF: PASS %s dataset create/reopen, exact values and metadata\n", argv[1]);
    return 0;
}
