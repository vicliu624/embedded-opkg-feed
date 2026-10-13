#include <ml_dtypes/include/float8.h>
#include <cmath>
#include <cstdio>

extern "C" void cdft(int n, int isgn, double* a, int* ip, double* w);

int main() {
    double values[] = {1, 0, 2, 0, 3, 0, 4, 0};
    const double expected[] = {1, 0, 2, 0, 3, 0, 4, 0};
    int work_indices[32] = {};
    double work_twiddles[32] = {};
    cdft(8, 1, values, work_indices, work_twiddles);
    cdft(8, -1, values, work_indices, work_twiddles);
    for (int i = 0; i < 8; ++i)
        if (!std::isfinite(values[i]) || std::fabs(values[i] / 4 - expected[i]) > 1e-12) return 1;
    const ml_dtypes::float8_e4m3fn low_precision(1.5f);
    if (static_cast<float>(low_precision) != 1.5f) return 2;
    const ml_dtypes::float8_e5m2 alternate(0.5f);
    if (static_cast<float>(alternate) != 0.5f) return 3;
    std::puts("FFT2D transform roundtrip and ml_dtypes low-precision values passed");
    return 0;
}
