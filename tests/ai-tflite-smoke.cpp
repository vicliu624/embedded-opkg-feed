#include <tensorflow/lite/interpreter.h>
#include <tensorflow/lite/kernels/register.h>
#include <tensorflow/lite/model_builder.h>
#include <tensorflow/lite/schema/schema_generated.h>
#include <cmath>
#include <cstdio>
#include <memory>

int main() {
    tflite::ModelT graph;
    graph.version = 3;
    auto code = std::make_unique<tflite::OperatorCodeT>();
    code->builtin_code = tflite::BuiltinOperator_ADD;
    code->deprecated_builtin_code = tflite::BuiltinOperator_ADD;
    code->version = 1;
    graph.operator_codes.push_back(std::move(code));
    graph.buffers.push_back(std::make_unique<tflite::BufferT>());
    auto subgraph = std::make_unique<tflite::SubGraphT>();
    for (int i = 0; i < 3; ++i) {
        auto tensor = std::make_unique<tflite::TensorT>();
        tensor->shape = {4};
        tensor->type = tflite::TensorType_FLOAT32;
        tensor->buffer = 0;
        subgraph->tensors.push_back(std::move(tensor));
    }
    subgraph->inputs = {0, 1};
    subgraph->outputs = {2};
    auto op = std::make_unique<tflite::OperatorT>();
    op->opcode_index = 0;
    op->inputs = {0, 1};
    op->outputs = {2};
    op->builtin_options.Set(tflite::AddOptionsT{});
    subgraph->operators.push_back(std::move(op));
    graph.subgraphs.push_back(std::move(subgraph));
    flatbuffers::FlatBufferBuilder buffer;
    tflite::FinishModelBuffer(buffer, tflite::Model::Pack(buffer, &graph));
    auto model = tflite::FlatBufferModel::BuildFromBuffer(
        reinterpret_cast<const char*>(buffer.GetBufferPointer()), buffer.GetSize());
    if (!model) return 1;
    tflite::ops::builtin::BuiltinOpResolver resolver;
    std::unique_ptr<tflite::Interpreter> interpreter;
    if (tflite::InterpreterBuilder(*model, resolver)(&interpreter) != kTfLiteOk) return 2;
    interpreter->SetNumThreads(1);
    if (interpreter->AllocateTensors() != kTfLiteOk) return 3;
    for (int i = 0; i < 4; ++i) {
        interpreter->typed_input_tensor<float>(0)[i] = static_cast<float>(i);
        interpreter->typed_input_tensor<float>(1)[i] = 0.5f;
    }
    if (interpreter->Invoke() != kTfLiteOk) return 4;
    for (int i = 0; i < 4; ++i) {
        const float result = interpreter->typed_output_tensor<float>(0)[i];
        if (!std::isfinite(result) || std::fabs(result - (i + 0.5f)) > 1e-6f) return 5;
    }
    std::puts("TensorFlow Lite serialized model loading and CPU inference passed");
    return 0;
}
