#include <gsl/gsl_errno.h>
#include <gsl/gsl_integration.h>
#include <gsl/gsl_linalg.h>
#include <gsl/gsl_fft_complex.h>
#include <gsl/gsl_statistics_double.h>
#include <math.h>
#include <stdio.h>

static double square(double x, void *unused) {
    (void)unused;
    return x * x;
}

int main(void) {
    gsl_set_error_handler_off();
    double coefficients[] = {3, 1, 1, 2};
    double rhs[] = {9, 8}, solution[2];
    gsl_matrix_view matrix = gsl_matrix_view_array(coefficients, 2, 2);
    gsl_vector_view b = gsl_vector_view_array(rhs, 2);
    gsl_vector_view x = gsl_vector_view_array(solution, 2);
    gsl_permutation *permutation = gsl_permutation_alloc(2);
    int sign;
    if (!permutation || gsl_linalg_LU_decomp(&matrix.matrix, permutation, &sign) ||
        gsl_linalg_LU_solve(&matrix.matrix, permutation, &b.vector, &x.vector)) return 1;
    gsl_permutation_free(permutation);
    if (fabs(solution[0] - 2) > 1e-12 || fabs(solution[1] - 3) > 1e-12) return 2;
    gsl_integration_workspace *workspace = gsl_integration_workspace_alloc(128);
    gsl_function function = {square, NULL};
    double result, error;
    if (!workspace || gsl_integration_qag(&function, 0, 1, 1e-12, 1e-12, 128,
        GSL_INTEG_GAUSS21, workspace, &result, &error)) return 3;
    gsl_integration_workspace_free(workspace);
    if (fabs(result - 1.0 / 3) > 1e-12 || error > 1e-12) return 4;
    double signal[] = {1, 0, 2, 0, 3, 0, 4, 0};
    if (gsl_fft_complex_radix2_forward(signal, 1, 4) ||
        gsl_fft_complex_radix2_inverse(signal, 1, 4)) return 5;
    for (int i = 0; i < 4; i++)
        if (fabs(signal[2 * i] - (i + 1)) > 1e-12 || fabs(signal[2 * i + 1]) > 1e-12) return 6;
    double values[] = {1, 2, 3, 4};
    if (fabs(gsl_stats_mean(values, 1, 4) - 2.5) > 1e-12) return 7;
    puts("GSL: PASS LU solve, adaptive integration, FFT roundtrip and statistics");
    return 0;
}
