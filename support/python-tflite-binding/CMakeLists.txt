cmake_minimum_required(VERSION 3.16)
project(tdvp_tflite_python_binding LANGUAGES CXX)
foreach(required TF_SOURCE_ROOT WRAPPER_SOURCE_ROOT TF_STAGE_ROOT PYTHON_STAGE_ROOT)
  if(NOT IS_DIRECTORY "${${required}}")
    message(FATAL_ERROR "Missing reviewed binding input: ${required}")
  endif()
endforeach()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_SKIP_RPATH ON)
find_library(TFLITE_LIBRARY NAMES tensorflow-lite PATHS "${TF_STAGE_ROOT}/usr/lib" NO_DEFAULT_PATH REQUIRED)
find_library(PYTHON_LIBRARY NAMES python3.13 PATHS "${PYTHON_STAGE_ROOT}/usr/lib" NO_DEFAULT_PATH REQUIRED)
find_package(absl CONFIG REQUIRED PATHS "${TF_STAGE_ROOT}/usr/lib/cmake/absl" NO_DEFAULT_PATH)
add_library(_pywrap_tensorflow_interpreter_wrapper MODULE
  "${WRAPPER_SOURCE_ROOT}/interpreter_wrapper.cc"
  "${TF_SOURCE_ROOT}/tensorflow/lite/python/interpreter_wrapper/interpreter_wrapper_pybind11.cc"
  "${TF_SOURCE_ROOT}/tensorflow/lite/python/interpreter_wrapper/numpy.cc"
  "${TF_SOURCE_ROOT}/tensorflow/lite/python/interpreter_wrapper/python_error_reporter.cc"
  "${TF_SOURCE_ROOT}/tensorflow/lite/python/interpreter_wrapper/python_utils.cc")
target_include_directories(_pywrap_tensorflow_interpreter_wrapper PRIVATE
  "${TF_SOURCE_ROOT}"
  "${TF_STAGE_ROOT}/usr/include"
  "${TF_STAGE_ROOT}/usr/include/eigen3"
  "${PYTHON_STAGE_ROOT}/usr/include"
  "${PYTHON_STAGE_ROOT}/usr/include/python3.13"
  "${PYTHON_STAGE_ROOT}/usr/lib/python3.13/site-packages/numpy/_core/include")
target_link_libraries(_pywrap_tensorflow_interpreter_wrapper PRIVATE
  "${TFLITE_LIBRARY}" "${PYTHON_LIBRARY}" absl::str_format ${CMAKE_DL_LIBS})
target_link_options(_pywrap_tensorflow_interpreter_wrapper PRIVATE
  "-Wl,--no-undefined" "-Wl,-rpath-link,${TF_STAGE_ROOT}/usr/lib"
  "-Wl,-rpath-link,${PYTHON_STAGE_ROOT}/usr/lib")
set_target_properties(_pywrap_tensorflow_interpreter_wrapper PROPERTIES PREFIX "")
