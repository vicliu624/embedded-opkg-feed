#include <fftw3.h>
#include <math.h>

int main(void)
{
    double input[8] = {1, 1, 1, 1, 1, 1, 1, 1};
    fftw_complex output[5];
    if (!fftw_init_threads()) return 1;
    fftw_plan_with_nthreads(2);
    fftw_plan plan = fftw_plan_dft_r2c_1d(8, input, output, FFTW_ESTIMATE);
    if (!plan) return 2;
    fftw_execute(plan);
    int result = fabs(output[0][0] - 8.0) > 1e-8;
    for (int i = 1; i < 5; ++i)
        result |= fabs(output[i][0]) > 1e-8 || fabs(output[i][1]) > 1e-8;
    fftw_destroy_plan(plan);
    fftw_cleanup_threads();
    return result ? 3 : 0;
}
