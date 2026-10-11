#include <netcdf.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define CHECK(call) do { int s=(call); if(s != NC_NOERR){fprintf(stderr,"%s: %s\n",#call,nc_strerror(s));return 1;} } while(0)

int main(int argc, char **argv) {
    if(argc != 3) return 64;
    int dap4 = strcmp(argv[1], "dap4") == 0;
    if(!dap4 && strcmp(argv[1], "dap2")) return 64;
    int file, variable, integer;
    double real;
    CHECK(nc_open(argv[2], NC_NOWRITE, &file));
    CHECK(nc_inq_varid(file, dap4 ? "v32" : "i32", &variable));
    CHECK(nc_get_var_int(file, variable, &integer));
    if(integer != (dap4 ? INT_MAX : 1)) return 2;
    CHECK(nc_inq_varid(file, dap4 ? "vd" : "f64", &variable));
    CHECK(nc_get_var_double(file, variable, &real));
    if(fabs(real - (dap4 ? 3.14159265358979 : 1000.0)) > 1e-12) return 3;
    if(dap4) {
        unsigned long long maximum;
        char *text = NULL;
        CHECK(nc_inq_varid(file, "vu64", &variable));
        CHECK(nc_get_var_ulonglong(file, variable, &maximum));
        if(maximum != ULLONG_MAX) return 4;
        CHECK(nc_inq_varid(file, "vs", &variable));
        CHECK(nc_get_var_string(file, variable, &text));
        if(!text || strcmp(text, "hello\tworld")) return 5;
        CHECK(nc_free_string(1, &text));
        nc_type type;
        size_t size;
        unsigned char opaque[16];
        const unsigned char expected[16] = {1,35,69,103,137,171,205,239,0,0,0,0,0,0,0,0};
        CHECK(nc_inq_varid(file, "vo", &variable));
        CHECK(nc_inq_vartype(file, variable, &type));
        CHECK(nc_inq_type(file, type, NULL, &size));
        if(size != sizeof(opaque)) return 6;
        CHECK(nc_get_var(file, variable, opaque));
        if(memcmp(opaque, expected, sizeof(opaque))) return 7;
        signed char cloud;
        CHECK(nc_inq_varid(file, "primary_cloud", &variable));
        CHECK(nc_get_var(file, variable, &cloud));
        if(cloud != 2) return 8;
    } else {
        char text[65] = {0};
        CHECK(nc_inq_varid(file, "s", &variable));
        CHECK(nc_get_var_text(file, variable, text));
        if(strcmp(text, "This is a data test string (pass 0).")) return 9;
    }
    CHECK(nc_close(file));
    printf("NetCDF %s official dataset consumer: PASS\n", argv[1]);
    return 0;
}
