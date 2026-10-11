cmake_minimum_required(VERSION 3.24)
project(tdvp_onnxruntime_python_probe LANGUAGES CXX)
# A local acceptance probe consuming existing ORT build outputs. This is not
# yet a published package build contract: inputs must be source/ABI attested.
foreach(input ORT_SOURCE_ROOT ORT_BUILD_ROOT TARGET_PYTHON_INCLUDE TARGET_NUMPY_INCLUDE)
  if(NOT IS_DIRECTORY "${${input}}")
    message(FATAL_ERROR "Missing probe input: ${input}")
  endif()
endforeach()
if(NOT EXISTS "${ORT_BUILD_ROOT}/CMakeCache.txt")
  message(FATAL_ERROR "ORT build configuration is required to attest RTTI compatibility")
endif()
file(STRINGS "${ORT_BUILD_ROOT}/CMakeCache.txt" ort_rtti_configuration
  REGEX "^onnxruntime_DISABLE_RTTI:BOOL=")
if(NOT ort_rtti_configuration STREQUAL "onnxruntime_DISABLE_RTTI:BOOL=OFF")
  message(FATAL_ERROR
    "Python bindings require an RTTI-enabled ORT core; reuse of the C-only no-RTTI core is unsafe")
endif()
find_package(ONNX CONFIG REQUIRED)
find_package(Protobuf CONFIG REQUIRED)
find_package(re2 CONFIG REQUIRED)
find_package(FlatBuffers CONFIG REQUIRED)
file(GLOB sources CONFIGURE_DEPENDS "${ORT_SOURCE_ROOT}/onnxruntime/python/*.cc")
add_library(onnxruntime_pybind11_state MODULE ${sources})
target_compile_features(onnxruntime_pybind11_state PRIVATE cxx_std_17)
target_compile_definitions(onnxruntime_pybind11_state PRIVATE
  NDEBUG EIGEN_MPL2_ONLY EIGEN_USE_THREADS ONLY_C_LOCALE=0 ONNX_ML=1
  ONNX_NAMESPACE=onnx ORT_ENABLE_STREAM PLATFORM_POSIX PROTOBUF_USE_DLLS)
target_include_directories(onnxruntime_pybind11_state PRIVATE
  "${ORT_SOURCE_ROOT}/include/onnxruntime"
  "${ORT_SOURCE_ROOT}/include/onnxruntime/core/session"
  "${ORT_SOURCE_ROOT}/onnxruntime" "${ORT_BUILD_ROOT}"
  "${TARGET_PYTHON_INCLUDE}" "${TARGET_NUMPY_INCLUDE}"
  "${CMAKE_SYSROOT}/usr/include" "${CMAKE_SYSROOT}/usr/include/eigen3"
  "${CMAKE_SYSROOT}/usr/include/safeint")
set(archives)
foreach(component session optimizer providers lora framework graph util mlas common flatbuffers)
  set(archive "${ORT_BUILD_ROOT}/libonnxruntime_${component}.a")
  if(NOT EXISTS "${archive}")
    message(FATAL_ERROR "Missing prebuilt component: ${archive}")
  endif()
  list(APPEND archives "${archive}")
endforeach()
target_link_libraries(onnxruntime_pybind11_state PRIVATE
  "$<LINK_GROUP:RESCAN,${archives}>" ONNX::onnx protobuf::libprotobuf
  re2::re2 flatbuffers::flatbuffers_shared pthread dl)
target_compile_options(onnxruntime_pybind11_state PRIVATE -fvisibility=hidden)
target_link_options(onnxruntime_pybind11_state PRIVATE
  "LINKER:--version-script=${ORT_SOURCE_ROOT}/onnxruntime/python/version_script.lds")
set(probe_python_root "${CMAKE_BINARY_DIR}/python")
# provider bridge remains owned by the public ORT runtime library package;
# upstream POSIX loading resolves its SONAME through the system loader.
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/build_and_package_info.py"
  "${probe_python_root}/onnxruntime/capi/build_and_package_info.py" COPYONLY)
configure_file("${ORT_SOURCE_ROOT}/onnxruntime/__init__.py"
  "${probe_python_root}/onnxruntime/__init__.py" COPYONLY)
foreach(module __init__ _ld_preload onnxruntime_collect_build_info
    onnxruntime_inference_collection onnxruntime_validation)
  configure_file("${ORT_SOURCE_ROOT}/onnxruntime/python/${module}.py"
    "${probe_python_root}/onnxruntime/capi/${module}.py" COPYONLY)
endforeach()
# CPU inference does not need CUDA/PyTorch loader policy or global dlopen flags.
set(ONNXRUNTIME_IMPORT_PYTORCH_TO_RESOLVE_DLLS "")
set(ONNXRUNTIME_SETDLOPENFLAGS_GLOBAL "")
set(ONNXRUNTIME_SETDLOPENFLAGS_LOCAL "")
configure_file("${ORT_SOURCE_ROOT}/onnxruntime/python/_pybind_state.py.in"
  "${probe_python_root}/onnxruntime/capi/_pybind_state.py" @ONLY)
set_target_properties(onnxruntime_pybind11_state PROPERTIES
  PREFIX "" SUFFIX ".so"
  LIBRARY_OUTPUT_DIRECTORY "${probe_python_root}/onnxruntime/capi")
