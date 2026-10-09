#include <date/date.h>
#include <date/tz.h>
#include <boost/mp11.hpp>
#include <chrono>
#include <cstdio>
#include <sstream>
#include <type_traits>

using Types = boost::mp11::mp_list<int, float, int>;
static_assert(boost::mp11::mp_size<Types>::value == 3, "MP11 type list size");
static_assert(boost::mp11::mp_size<boost::mp11::mp_unique<Types>>::value == 2, "MP11 unique types");
static_assert(boost::mp11::mp_count<Types, int>::value == 2, "MP11 type counting");

int main() {
    const date::sys_days leap = date::year{2024}/date::February/29;
    std::ostringstream formatted;
    formatted << date::format("%F", leap);
    if (formatted.str() != "2024-02-29") return 1;
    const auto* zone = date::locate_zone("Asia/Shanghai");
    if (!zone) return 2;
    const auto epoch = date::sys_seconds{};
    const auto info = zone->get_info(epoch);
    if (info.offset != std::chrono::hours(8)) return 3;
    std::puts("date formatting/timezone and Boost.MP11 consumer checks passed");
    return 0;
}
