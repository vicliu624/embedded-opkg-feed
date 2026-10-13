# CPU0 has no RVV; portable emulated vectors retain contrib sort support.
add_compile_definitions(HWY_COMPILE_ONLY_EMU128)
add_compile_options(-march=rv64imafdc -mabi=lp64d)
add_link_options(-march=rv64imafdc -mabi=lp64d)
