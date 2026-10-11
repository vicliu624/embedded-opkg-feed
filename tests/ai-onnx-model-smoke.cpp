#include <onnx/onnx_pb.h>
#include <onnx/checker.h>
#include <onnx/shape_inference/implementation.h>
#include <fstream>
#include <cstdio>
#include <string>

int main(int argc, char** argv) {
    onnx::ModelProto model;
    model.set_ir_version(8);
    model.set_producer_name("tdvp-runtime-validation");
    model.add_opset_import()->set_version(13);
    auto* graph = model.mutable_graph();
    graph->set_name("identity");
    auto* input = graph->add_input();
    input->set_name("x");
    auto* type = input->mutable_type()->mutable_tensor_type();
    type->set_elem_type(onnx::TensorProto_DataType_FLOAT);
    type->mutable_shape()->add_dim()->set_dim_value(2);
    auto* output = graph->add_output();
    output->CopyFrom(*input);
    output->set_name("y");
    auto* node = graph->add_node();
    node->set_op_type("Identity");
    node->add_input("x");
    node->add_output("y");
    onnx::checker::check_model(model);
    std::string encoded;
    if (!model.SerializeToString(&encoded)) return 1;
    onnx::ModelProto decoded;
    if (!decoded.ParseFromString(encoded)) return 2;
    onnx::checker::check_model(decoded);
    onnx::shape_inference::InferShapes(decoded);
    if (decoded.graph().output(0).type().tensor_type().shape().dim(0).dim_value() != 2) return 3;
    if (argc == 2) {
        std::ofstream file(argv[1], std::ios::binary | std::ios::trunc);
        if (!file || !decoded.SerializeToOstream(&file)) return 4;
    }
    std::puts("ONNX model serialization, checking and shape inference passed");
    return 0;
}
