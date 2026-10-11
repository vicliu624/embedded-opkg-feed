#include <onnxruntime_cxx_api.h>
#include <array>
#include <cmath>
#include <cstdio>

int main(int argc, char** argv) {
    if (argc != 2) return 64;
    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "tdvp-runtime-validation");
    Ort::SessionOptions options;
    options.SetIntraOpNumThreads(1);
    options.SetInterOpNumThreads(1);
    Ort::Session session(env, argv[1], options);
    std::array<float, 2> input = {1.25f, -3.0f};
    const std::array<int64_t, 1> shape = {2};
    auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    auto tensor = Ort::Value::CreateTensor<float>(memory, input.data(), input.size(), shape.data(), shape.size());
    const char* input_names[] = {"x"};
    const char* output_names[] = {"y"};
    auto outputs = session.Run(Ort::RunOptions{nullptr}, input_names, &tensor, 1, output_names, 1);
    if (outputs.size() != 1 || !outputs[0].IsTensor()) return 1;
    const auto info = outputs[0].GetTensorTypeAndShapeInfo();
    if (info.GetElementCount() != input.size() || info.GetElementType() != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) return 2;
    const float* result = outputs[0].GetTensorData<float>();
    for (size_t i = 0; i < input.size(); ++i)
        if (!std::isfinite(result[i]) || std::fabs(result[i] - input[i]) > 1e-6f) return 3;
    std::puts("ONNX Runtime model loading and CPU inference passed");
    return 0;
}
