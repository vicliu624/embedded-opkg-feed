#include <netcdf.h>
#include <stdio.h>

int main(int argc, char **argv) {
    if (argc != 2) return 64;
    int file, variable, status = nc_open(argv[1], NC_NOWRITE, &file);
    if (status) { fprintf(stderr, "%s\n", nc_strerror(status)); return 1; }
    if (nc_inq_varid(file, "values", &variable)) return 2;
    double values[4];
    if (nc_get_var_double(file, variable, values)) return 3;
    const double expected[] = {1.25, -2.5, 0, 1024.125};
    for (int i = 0; i < 4; i++) if (values[i] != expected[i]) return 4;
    if (nc_close(file)) return 5;
    puts("NetCDF remote: PASS HTTP byte-range exact dataset values");
    return 0;
}
