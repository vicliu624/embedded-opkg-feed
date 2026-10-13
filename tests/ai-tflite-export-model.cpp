#include <tensorflow/lite/schema/schema_generated.h>
#include <cstdio>
#include <memory>

int main(int argc, char **argv) {
    if (argc != 2) return 1;
    tflite::ModelT model;
    model.version = 3;
    auto code = std::make_unique<tflite::OperatorCodeT>();
    code->builtin_code = tflite::BuiltinOperator_ADD;
    code->deprecated_builtin_code = tflite::BuiltinOperator_ADD;
    code->version = 1;
    model.operator_codes.push_back(std::move(code));
    model.buffers.push_back(std::make_unique<tflite::BufferT>());
    auto graph = std::make_unique<tflite::SubGraphT>();
    for (int i = 0; i < 3; i++) {
        auto tensor = std::make_unique<tflite::TensorT>();
        tensor->shape = {4};
        tensor->shape_signature = {-1};
        tensor->type = tflite::TensorType_FLOAT32;
        tensor->buffer = 0;
        tensor->name = "tensor" + std::to_string(i);
        graph->tensors.push_back(std::move(tensor));
    }
    graph->inputs = {0, 1};
    graph->outputs = {2};
    auto operation = std::make_unique<tflite::OperatorT>();
    operation->inputs = {0, 1};
    operation->outputs = {2};
    operation->opcode_index = 0;
    operation->builtin_options.Set(tflite::AddOptionsT{});
    graph->operators.push_back(std::move(operation));
    model.subgraphs.push_back(std::move(graph));
    flatbuffers::FlatBufferBuilder buffer;
    tflite::FinishModelBuffer(buffer, tflite::Model::Pack(buffer, &model));
    FILE *file = fopen(argv[1], "wb");
    if (!file) return 2;
    const auto size = fwrite(buffer.GetBufferPointer(), 1, buffer.GetSize(), file);
    if (fclose(file) != 0 || size != buffer.GetSize()) return 3;
    puts("TFLite dynamic ADD test model exported: PASS");
    return 0;
}
