cmake_minimum_required(VERSION 3.20)

set(REPO ${CMAKE_CURRENT_LIST_DIR}/ttt)
set(GN ${CMAKE_CURRENT_LIST_DIR}/../gn/out/gn)
set(options0
    angle_build_tests=false
    angle_enable_abseil=true
    angle_enable_renderdoc=false
    angle_enable_swiftshader=false
    angle_enable_vulkan=true
    angle_enable_wgpu=false
    angle_expose_non_conformant_extensions_and_versions=true
    #angle_use_wayland=true
    angle_use_x11=false
    build_angle_deqp_tests=false
    build_with_chromium=false
    chrome_pgo_phase=0
    is_cfi=false
    is_component_build=false
    is_clang=false
    is_debug=false
    is_official_build=true
    treat_warnings_as_errors=false
    use_custom_libcxx=false
    use_safe_libstdcxx=true
    use_siso=false
    use_sysroot=false
)
string(REPLACE ";" " " options "${options0}")
message(STATUS "${options}")

file(COPY_FILE 
    ${CMAKE_CURRENT_LIST_DIR}/angle_gclient_args.gni
    ${REPO}/build/config/gclient_args.gni)

file(MAKE_DIRECTORY ${REPO}/third_party/rust-toolchain)
file(WRITE ${REPO}/third_party/rust-toolchain/VERSION "bogus")

execute_process(COMMAND
    ${GN} gen out --args=${options}
    WORKING_DIRECTORY ${REPO}
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to configure: ${rr}")
endif()

# FIXME: Link third_party/jsoncpp_source => third_party/jsoncpp/source
execute_process(COMMAND
    ln -s ${REPO}/third_party/jsoncpp_source ${REPO}/third_party/jsoncpp/source
    RESULT_VARIABLE rr)
if(rr)
    # FIXME: Ignore error (for "file exists")
    message(STATUS "Failed to link jsoncpp_source")
endif()

set(fake_clang_binaries
    llvm-strip
    llvm-otool
    llvm-nm
    clang
    clang++)

set(fake_clang /usr/bin/clang)
set(fake_clang++ /usr/bin/clang++)
set(fake_llvm-otool ${CMAKE_CURRENT_LIST_DIR}/fakebin/otool.sh)
set(fake_llvm-strip ${CMAKE_CURRENT_LIST_DIR}/fakebin/strip.sh)
set(fake_llvm-nm ${CMAKE_CURRENT_LIST_DIR}/fakebin/nm.sh)
set(fake_clang_basepath ${REPO}/third_party/llvm-build/Release+Asserts/bin)
file(MAKE_DIRECTORY ${fake_clang_basepath})
foreach(e IN LISTS fake_clang_binaries)
    execute_process(COMMAND
        ln -s ${fake_${e}} ${fake_clang_basepath}/${e}
        # FIXME: Ignore error
    )
endforeach()
set(fake_llvm_basepath ${REPO}/tools/clang)
set(fake_dsymutil ${fake_llvm_basepath}/dsymutil/bin/dsymutil)
set(fake_llvm_binaries
    dsymutil
)
foreach(e IN LISTS fake_llvm_binaries)
    cmake_path(GET fake_${e} PARENT_PATH dir)
    file(MAKE_DIRECTORY ${dir})
    execute_process(COMMAND
        ln -s /usr/bin/${e} ${fake_${e}}
        # FIXME: Ignore error
    )
endforeach()

execute_process(COMMAND
    ninja -C out
    WORKING_DIRECTORY ${REPO}
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to build: ${rr}")
endif()

