#include <net.h>
#include <cmath>
#include <cstdio>

int main() {
    ncnn::Net net;
    net.opt.num_threads = 1;
    net.opt.use_vulkan_compute = false;
    net.opt.use_packing_layout = false;
    const char* graph =
        "7767517\n"
        "2 2\n"
        "Input input 0 1 data\n"
        "ReLU relu 1 1 data result 0=0\n";
    if (net.load_param_mem(graph)) return 1;
    ncnn::Mat input(4);
    input[0] = -2.0f;
    input[1] = -0.5f;
    input[2] = 0.0f;
    input[3] = 3.0f;
    auto extractor = net.create_extractor();
    if (extractor.input("data", input)) return 2;
    ncnn::Mat output;
    if (extractor.extract("result", output)) return 3;
    if (output.total() != 4) return 4;
    const float expected[] = {0.0f, 0.0f, 0.0f, 3.0f};
    for (int i = 0; i < 4; ++i)
        if (!std::isfinite(output[i]) || std::fabs(output[i] - expected[i]) > 1e-6f) return 5;
    std::puts("ncnn CPU inference runtime smoke passed");
    return 0;
}
