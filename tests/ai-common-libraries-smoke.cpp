#include <cjson/cJSON.h>
#include <cjson/cJSON_Utils.h>
#include <double-conversion/double-conversion.h>
#include <yaml-cpp/yaml.h>
#include <cmath>
#include <cstdio>
#include <cstring>

int main() {
    cJSON* value = cJSON_Parse("{\"values\":[1,2,3],\"ready\":true}");
    if (!value) return 1;
    cJSON* item = cJSONUtils_GetPointer(value, "/values/2");
    if (!cJSON_IsNumber(item) || item->valuedouble != 3.0) return 2;
    char* encoded = cJSON_PrintUnformatted(value);
    if (!encoded || !std::strstr(encoded, "\"ready\":true")) return 3;
    cJSON_free(encoded);
    cJSON_Delete(value);

    const auto yaml = YAML::Load("name: tdvp\nvalues: [1, 2, 3]\nenabled: true\n");
    if (yaml["name"].as<std::string>() != "tdvp" ||
        !yaml["enabled"].as<bool>() || yaml["values"][2].as<int>() != 3) return 4;
    const auto roundtrip = YAML::Load(YAML::Dump(yaml));
    if (roundtrip["values"].size() != 3) return 5;

    char text[64];
    double_conversion::StringBuilder builder(text, sizeof text);
    if (!double_conversion::DoubleToStringConverter::EcmaScriptConverter().ToShortest(0.125, &builder)) return 6;
    if (std::strcmp(builder.Finalize(), "0.125")) return 7;
    double_conversion::StringToDoubleConverter parser(0, 0.0, -1.0, nullptr, nullptr);
    int consumed = 0;
    const double number = parser.StringToDouble("0.125", 5, &consumed);
    if (consumed != 5 || std::fabs(number - 0.125) > 1e-12) return 8;
    std::puts("cJSON, YAML and double-conversion runtime smoke passed");
    return 0;
}
