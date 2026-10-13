#include <google/protobuf/struct.pb.h>
#include <fstream>
#include <iostream>

int main(int argc, char **argv) {
    if (argc != 2) return 64;
    google::protobuf::Struct message;
    std::ifstream input(argv[1], std::ios::binary);
    if (!input || !message.ParseFromIstream(&input)) return 1;
    if (message.fields().at("counter").number_value() != 42) return 2;
    if (message.fields().at("label").string_value() != "tdvp") return 3;
    if (!message.fields().at("nested").struct_value().fields().at("ok").bool_value()) return 4;
    std::cout << "Native Python upb to public C++ Protobuf wire interoperability: PASS\n";
    return 0;
}
