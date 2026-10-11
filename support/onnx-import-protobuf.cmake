# Reuse the target provider's exported graph rather than searching native
# protoc's prefix for target libraries or downloading another Protobuf.
find_package(Protobuf CONFIG REQUIRED)
