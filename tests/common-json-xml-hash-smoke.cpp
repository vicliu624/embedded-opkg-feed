#include <json/json.h>
#include <pugixml.hpp>
#include <tinyxml2.h>
#include <xxhash.h>
#include <cstdio>
#include <memory>
#include <sstream>
#include <string>

int main() {
    Json::CharReaderBuilder reader_builder;
    std::unique_ptr<Json::CharReader> reader(reader_builder.newCharReader());
    Json::Value value;
    std::string error;
    const std::string document = "{\"name\":\"TDVP\",\"models\":[\"vision\",\"audio\"],\"enabled\":true}";
    if (!reader->parse(document.data(), document.data() + document.size(), &value, &error)) return 1;
    if (value["name"].asString() != "TDVP" || value["models"].size() != 2 || !value["enabled"].asBool()) return 2;
    Json::StreamWriterBuilder writer;
    const std::string roundtrip = Json::writeString(writer, value);
    Json::Value restored;
    if (!reader->parse(roundtrip.data(), roundtrip.data() + roundtrip.size(), &restored, &error) || restored != value) return 3;
    const std::string invalid = "{broken";
    if (reader->parse(invalid.data(), invalid.data() + invalid.size(), &restored, &error)) return 4;

    pugi::xml_document xml;
    if (!xml.load_string("<models><model type='vision' name='yolo'/><model type='audio' name='asr'/></models>")) return 5;
    auto selected = xml.select_nodes("/models/model[@type='vision']");
    if (selected.size() != 1 || std::string(selected[0].node().attribute("name").value()) != "yolo") return 6;
    std::ostringstream serialized;
    xml.save(serialized);
    pugi::xml_document parsed;
    if (!parsed.load_string(serialized.str().c_str()) || parsed.child("models").child("model").empty()) return 7;
    if (parsed.load_string("<models>")) return 8;

    tinyxml2::XMLDocument tiny;
    if (tiny.Parse("<config enabled='true'><threshold>0.75</threshold></config>") != tinyxml2::XML_SUCCESS) return 9;
    bool enabled = false;
    double threshold = 0;
    auto config = tiny.FirstChildElement("config");
    if (!config || config->QueryBoolAttribute("enabled", &enabled) != tinyxml2::XML_SUCCESS || !enabled) return 10;
    if (config->FirstChildElement("threshold")->QueryDoubleText(&threshold) != tinyxml2::XML_SUCCESS || threshold != 0.75) return 11;
    if (tiny.Parse("<config>") == tinyxml2::XML_SUCCESS) return 12;

    if (XXH_versionNumber() != 803 || XXH64("", 0, 0) != 0xef46db3751d8e999ULL) return 13;
    const std::string input = "TDVP model cache identity";
    const auto expected = XXH64(input.data(), input.size(), 123);
    XXH64_state_t *state = XXH64_createState();
    if (!state || XXH64_reset(state, 123) != XXH_OK) return 14;
    if (XXH64_update(state, input.data(), 7) != XXH_OK || XXH64_update(state, input.data() + 7, input.size() - 7) != XXH_OK) return 15;
    const auto actual = XXH64_digest(state);
    XXH64_freeState(state);
    if (actual != expected || XXH64(input.data(), input.size(), 124) == expected) return 16;
    std::puts("JsonCpp round trip/rejection, pugixml XPath, TinyXML2 parse/rejection, xxHash streaming/vector: PASS");
    return 0;
}
