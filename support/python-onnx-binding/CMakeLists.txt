cmake_minimum_required(VERSION 3.20)
project(tdvp_python_onnx_binding LANGUAGES CXX)
find_package(ONNX CONFIG REQUIRED)
foreach(input ONNX_SOURCE_ROOT TDVP_TARGET_PYTHON_INCLUDE TDVP_PYBIND11_INCLUDE)
  if(NOT IS_DIRECTORY "${${input}}")
    message(FATAL_ERROR "Missing binding input: ${input}")
  endif()
endforeach()
# The published shared provider owns all model/schema implementation code.
# Compile only the upstream Python wrapper translation unit.
add_library(onnx_cpp2py_export MODULE "${ONNX_SOURCE_ROOT}/onnx/cpp2py_export.cc")
target_link_libraries(onnx_cpp2py_export PRIVATE ONNX::onnx)
target_include_directories(onnx_cpp2py_export PRIVATE
  "${ONNX_SOURCE_ROOT}" "${TDVP_TARGET_PYTHON_INCLUDE}" "${TDVP_PYBIND11_INCLUDE}")
target_compile_features(onnx_cpp2py_export PRIVATE cxx_std_17)
target_compile_definitions(onnx_cpp2py_export PRIVATE NDEBUG)
set_target_properties(onnx_cpp2py_export PROPERTIES PREFIX "" CXX_VISIBILITY_PRESET hidden)
