#include <onnx/checker.h>
#include <onnx/onnx_pb.h>
#include <onnxruntime_cxx_api.h>
#include <array>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <string>

int main(int argc, char** argv) {
    if (argc != 3) return 64;
    auto check_model = [&]() {
        std::ifstream file(argv[1], std::ios::binary);
        onnx::ModelProto model;
        if (!file || !model.ParseFromIstream(&file)) throw std::runtime_error("model parse failed");
        onnx::checker::check_model(model);
        auto invalid = model;
        invalid.mutable_graph()->mutable_node(0)->set_op_type("DefinitelyMissingTdvpOperator");
        bool rejected = false;
        try { onnx::checker::check_model(invalid); }
        catch (const std::exception&) { rejected = true; }
        if (!rejected) throw std::runtime_error("invalid model was accepted");
    };
    const bool public_first = std::string(argv[2]) == "public-first";
    for (int repeat = 0; repeat < 2; ++repeat) {
        if (public_first) check_model();
        Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "tdvp-schema-coexistence");
        Ort::SessionOptions options;
        options.SetIntraOpNumThreads(1);
        options.SetInterOpNumThreads(1);
        Ort::Session session(env, argv[1], options);
        std::array<float, 2> input = {1.25f, -3.0f};
        const std::array<int64_t, 1> shape = {2};
        auto memory = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
        auto tensor = Ort::Value::CreateTensor<float>(memory, input.data(), input.size(), shape.data(), shape.size());
        const char* inputs[] = {"x"};
        const char* outputs[] = {"y"};
        auto result = session.Run(Ort::RunOptions{nullptr}, inputs, &tensor, 1, outputs, 1);
        if (result.size() != 1 || result[0].GetTensorTypeAndShapeInfo().GetElementCount() != 2) return 1;
        const float* data = result[0].GetTensorData<float>();
        for (size_t i = 0; i < input.size(); ++i)
            if (!std::isfinite(data[i]) || std::fabs(data[i] - input[i]) > 1e-6f) return 2;
        check_model();
    }
    std::puts("Public ONNX checking and ONNX Runtime coexistence/order tests passed");
    return 0;
}
