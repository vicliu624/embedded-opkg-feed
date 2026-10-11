#include <onnx/defs/schema.h>
#include <cstdio>

int main() {
#ifndef NDEBUG
    std::printf("ONNX debug schema macro count: %zu\n", onnx::DbgOperatorSetTracker::Instance().GetCount());
#else
    std::puts("ONNX release consumer: debug schema tracking disabled");
#endif
    return 0;
}
