#include <nlohmann/json.hpp>
#include <farmhash.h>
#include <cstdio>
#include <string>

int main() {
    using nlohmann::json;
    const auto value = json::parse("{\"camera\":\"cpu1\",\"frames\":[1,2,3],\"ready\":true}");
    if (value["camera"] != "cpu1" || value["frames"][2] != 3 || !value["ready"].get<bool>()) return 1;
    if (json::parse(value.dump()) != value) return 2;
    if (json::from_cbor(json::to_cbor(value)) != value) return 3;
    if (json::from_msgpack(json::to_msgpack(value)) != value) return 4;
    const std::string input = value.dump();
    const auto first = util::Fingerprint64(input.data(), input.size());
    if (first != util::Fingerprint64(input.data(), input.size())) return 5;
    const std::string different = input + "!";
    if (first == util::Fingerprint64(different.data(), different.size())) return 6;
    std::puts("nlohmann JSON/CBOR/MessagePack and FarmHash runtime smoke passed");
    return 0;
}
