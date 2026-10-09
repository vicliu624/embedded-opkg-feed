# TensorFlow Lite's benchmark/profiling targets refer to protobuf even when
# building just the interpreter library. Resolve it from the target sysroot;
# host protoc remains an explicitly supplied native build input.
find_package(Protobuf CONFIG REQUIRED)
find_package(FlatBuffers CONFIG REQUIRED)
if(NOT TARGET flatbuffers::flatbuffers AND TARGET flatbuffers::flatbuffers_shared)
  add_library(flatbuffers::flatbuffers ALIAS flatbuffers::flatbuffers_shared)
endif()
