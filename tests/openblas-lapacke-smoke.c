#include <lapacke.h>
#include <math.h>
#include <stdio.h>

_Static_assert(sizeof(lapack_int) == 4, "TDVP OpenBLAS uses LP64 LAPACK integers");

int main(void) {
    double a[] = {3, 1, 1, 2}, b[] = {9, 8};
    lapack_int pivots[2];
    if (LAPACKE_dgesv(LAPACK_ROW_MAJOR, 2, 1, a, 2, pivots, b, 1)) return 1;
    if (fabs(b[0] - 2) > 1e-12 || fabs(b[1] - 3) > 1e-12) return 2;
    double diagonal[] = {3, 0, 0, 2}, values[2];
    if (LAPACKE_dsyev(LAPACK_ROW_MAJOR, 'V', 'U', 2, diagonal, 2, values)) return 3;
    if (fabs(values[0] - 2) > 1e-12 || fabs(values[1] - 3) > 1e-12) return 4;
    puts("OpenBLAS LAPACKE: PASS LP64 linear solve and symmetric eigensystem");
    return 0;
}
