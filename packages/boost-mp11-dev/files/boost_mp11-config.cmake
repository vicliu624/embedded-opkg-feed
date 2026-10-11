get_filename_component(_tdvp_mp11_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
if(NOT TARGET Boost::mp11)
  add_library(Boost::mp11 INTERFACE IMPORTED GLOBAL)
  set_target_properties(Boost::mp11 PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_tdvp_mp11_prefix}/include"
    INTERFACE_COMPILE_FEATURES "cxx_alias_templates;cxx_variadic_templates;cxx_decltype")
endif()
set(boost_mp11_FOUND TRUE)
unset(_tdvp_mp11_prefix)
