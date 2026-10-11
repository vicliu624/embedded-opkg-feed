#include <cpuinfo.h>
#include <gemmlowp/fixedpoint/fixedpoint.h>
#include <cstdio>
#include <cstdint>

int main() {
    using Q0 = gemmlowp::FixedPoint<int32_t, 0>;
    const auto half = Q0::FromRaw(1 << 30);
    if ((half * half).raw() != (1 << 29)) return 1;
    if ((half * Q0::Zero()).raw() != 0) return 2;
    // Discovery may be unavailable under user-mode emulation; consumers must
    // tolerate that without reading null processor records or enabling SIMD.
    const bool initialized = cpuinfo_initialize();
    if (initialized && cpuinfo_get_processors_count() && !cpuinfo_get_processors()) return 3;
    std::printf("gemmlowp fixed-point arithmetic passed; cpuinfo initialized=%d\n", initialized);
    cpuinfo_deinitialize();
    return 0;
}
