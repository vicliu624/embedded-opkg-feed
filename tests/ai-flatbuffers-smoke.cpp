#include <flatbuffers/idl.h>
#include <flatbuffers/util.h>
#include <string>
#include <cstdio>

int main()
{
    flatbuffers::Parser parser;
    if (!parser.Parse("table Result { score:float; label:string; } root_type Result;")) {
        std::fprintf(stderr, "schema: %s\n", parser.error_.c_str()); return 1;
    }
    if (!parser.Parse("{ score: 0.75, label: \"object\" }")) {
        std::fprintf(stderr, "data: %s\n", parser.error_.c_str()); return 2;
    }
    std::string json;
    const char *error = flatbuffers::GenerateText(parser, parser.builder_.GetBufferPointer(), &json);
    if (error) { std::fprintf(stderr, "text: %s\n", error); return 3; }
    return json.find("object") != std::string::npos && json.find("0.75") != std::string::npos ? 0 : 4;
}
