#include <fmt/format.h>
#include <spdlog/spdlog.h>
#include <spdlog/sinks/ostream_sink.h>
#include <memory>
#include <sstream>
#include <string>
#include <cstdio>

int main() {
    if (fmt::format("{}:{:.2f}", "tdvp", 1.25) != "tdvp:1.25") return 1;
    std::ostringstream output;
    auto sink = std::make_shared<spdlog::sinks::ostream_sink_mt>(output);
    spdlog::logger logger("runtime-test", sink);
    logger.set_pattern("%v");
    logger.info("{} {}", "tdvp", 42);
    logger.flush();
    if (output.str() != "tdvp 42\n") return 2;
    std::puts("fmt formatting and spdlog runtime logging passed");
    return 0;
}
