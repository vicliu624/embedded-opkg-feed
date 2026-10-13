#include <re2/re2.h>
#include <gsl/gsl>
#include <SafeInt.hpp>
#include <cstdint>
#include <limits>
#include <cstdio>
#include <string>

int main() {
    std::string name;
    int number = 0;
    if (!RE2::FullMatch("camera-42", "([a-z]+)-([0-9]+)", &name, &number)) return 1;
    if (name != "camera" || number != 42) return 2;
    if (RE2::FullMatch("camera-x", "camera-[0-9]+")) return 3;
    int values[] = {1, 2, 3};
    gsl::span<int> span(values);
    if (span.size() != 3 || gsl::at(span, 2) != 3) return 4;
    SafeInt<int32_t> safe(7);
    safe *= 6;
    if (static_cast<int32_t>(safe) != 42) return 5;
    bool rejected = false;
    try {
        SafeInt<int32_t> maximum(std::numeric_limits<int32_t>::max());
        maximum += 1;
    } catch (const SafeIntException&) {
        rejected = true;
    }
    if (!rejected) return 6;
    std::puts("RE2 matching, GSL span and SafeInt overflow checks passed");
    return 0;
}
