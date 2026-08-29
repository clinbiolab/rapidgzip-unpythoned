cmake_minimum_required(VERSION 3.17)

project(rapidgzip-unpythoned VERSION 0.16.0 LANGUAGES C CXX)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(FATAL_ERROR
        "rapidgzip-unpythoned currently supports only Linux x86-64. "
        "macOS and Windows require separately validated production policies.")
endif()
if(NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
    message(FATAL_ERROR
        "rapidgzip-unpythoned currently supports only Linux x86-64; "
        "CMAKE_SYSTEM_PROCESSOR is '${CMAKE_SYSTEM_PROCESSOR}'.")
endif()

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING
        "Build type (the production configuration is RelWithDebInfo)" FORCE)
endif()
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_C_COMPILER_ID MATCHES "^(Clang|GNU)$" OR
   NOT CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|GNU)$")
    message(FATAL_ERROR "This Linux milestone supports Clang or GNU C/C++ toolchains only.")
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND
   CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 19)
    message(STATUS
        "Release-fidelity compiler: ${CMAKE_CXX_COMPILER_ID} "
        "${CMAKE_CXX_COMPILER_VERSION}; rapidgzip.cpp will use C++2c")
else()
    message(WARNING
        "The pinned upstream Linux release uses Clang 19 with C++2c. "
        "This compiler is supported for local builds but is not that release toolchain: "
        "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}.")
endif()

option(RAPIDGZIP_REQUIRE_IPO
    "Fail release configuration when IPO/LTO is unavailable" ON)

if(CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo)$")
    include(CheckIPOSupported)
    check_ipo_supported(RESULT RAPIDGZIP_IPO_SUPPORTED
                        OUTPUT RAPIDGZIP_IPO_ERROR
                        LANGUAGES C CXX)
    if(RAPIDGZIP_IPO_SUPPORTED)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
        message(STATUS "Production IPO/LTO: enabled")
    elseif(RAPIDGZIP_REQUIRE_IPO)
        message(FATAL_ERROR
            "IPO/LTO is required for a release-equivalent build but is unavailable: "
            "${RAPIDGZIP_IPO_ERROR}")
    else()
        message(WARNING
            "IPO/LTO is unavailable. This explicitly requested build is not "
            "release-equivalent: ${RAPIDGZIP_IPO_ERROR}")
    endif()
else()
    message(WARNING
        "CMAKE_BUILD_TYPE='${CMAKE_BUILD_TYPE}' is not the production "
        "RelWithDebInfo configuration; IPO/LTO was not requested.")
endif()

# Reproduce the warning and Linux x86-64 hardening policy from pinned
# librapidarchive/CMakeLists.txt. Upstream applies the hardening flags to C++
# only, while its dependency C objects receive the warning policy and PIC/LTO.
add_compile_options(
    "$<$<OR:$<COMPILE_LANG_AND_ID:C,Clang>,$<COMPILE_LANG_AND_ID:CXX,Clang>>:-Wall;-Wextra;-Wshadow;-Werror=return-type;-Wno-unknown-attributes>"
    "$<$<OR:$<COMPILE_LANG_AND_ID:C,GNU>,$<COMPILE_LANG_AND_ID:CXX,GNU>>:-Wall;-Wextra;-Wshadow;-Wunused;-Werror=return-type;-Wno-attributes>"
    "$<$<COMPILE_LANG_AND_ID:CXX,GNU>:-Wsuggest-override>"
    "$<$<COMPILE_LANG_AND_ID:CXX,Clang,GNU>:-fpie;-fstack-protector-strong;-fstack-clash-protection;-fcf-protection=full>"
)

set(RAPIDGZIP_UPSTREAM_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/external/rapidgzip")
set(RAPIDGZIP_LIBRAPIDARCHIVE_ROOT "${RAPIDGZIP_UPSTREAM_ROOT}/librapidarchive")
set(RAPIDGZIP_SOURCE_ROOT "${RAPIDGZIP_LIBRAPIDARCHIVE_ROOT}/src")
set(RAPIDGZIP_ZLIB_NG_ROOT "${RAPIDGZIP_SOURCE_ROOT}/external/zlib-ng")
set(RAPIDGZIP_ISAL_ROOT "${RAPIDGZIP_SOURCE_ROOT}/external/isa-l")
set(RAPIDGZIP_RPMALLOC_ROOT "${RAPIDGZIP_SOURCE_ROOT}/external/rpmalloc/rpmalloc")
set(RAPIDGZIP_CXXOPTS_ROOT "${RAPIDGZIP_SOURCE_ROOT}/external/cxxopts/include")

function(rapidgzip_require_file path)
    if(NOT EXISTS "${path}")
        message(FATAL_ERROR
            "Required pinned upstream file is missing: ${path}\n"
            "Clone this repository with --recursive, or initialize its submodules "
            "manually before configuring. The build will not update submodules.")
    endif()
endfunction()

function(rapidgzip_assert_sha256 path expected description)
    rapidgzip_require_file("${path}")
    file(SHA256 "${path}" actual)
    if(NOT actual STREQUAL expected)
        message(FATAL_ERROR
            "${description} changed at ${path}.\n"
            "Expected SHA-256: ${expected}\n"
            "Actual SHA-256:   ${actual}\n"
            "Audit the pinned upstream production graph before updating this harness.")
    endif()
endfunction()

# These guards make a future submodule update require a deliberate review of
# the explicit source/feature mapping below. They inspect files only; no Git
# command is run during configuration.
rapidgzip_assert_sha256(
    "${RAPIDGZIP_SOURCE_ROOT}/CMakeLists.txt"
    "eafe2391a290b43bcad98ea742a38929000c1cc70b433ba6b805695626704ef9"
    "Pinned librapidarchive dependency definition")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_ISAL_ROOT}/CMakeLists.txt"
    "92b76160083864c14b752cba4b23d5529e0f179b37666dbb11406180b3aa1874"
    "Pinned ISA-L target definition")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_ISAL_ROOT}/cmake/crc.cmake"
    "59c50c1f66b5b1efc7320bdc0816688bb96c7338c64fc847c5681c37dcaea66c"
    "Pinned ISA-L CRC source selection")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_ISAL_ROOT}/cmake/igzip.cmake"
    "fca57d655a02cd90863ab5fdaf61d8fa40f4f441d451d7586dbc18063e5f90bc"
    "Pinned ISA-L igzip source selection")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_SOURCE_ROOT}/rapidgzip/rapidgzip.hpp"
    "29cf03120634ca32fd7b70e40751d19850097da0010aec2d39ceacb2eb912be2"
    "Pinned rapidgzip version header")

set(RAPIDGZIP_ZLIB_NG_RELATIVE_SOURCES
    # Keep this list in the same order as the zlib-ng block in the guarded
    # librapidarchive/src/CMakeLists.txt. Do not replace it with a glob or with
    # zlib-ng's standalone CMake target: that selects a different SIMD graph.
    cpu_features.c
    inflate.c
    adler32.c
    crc32.c
    crc32_braid_comb.c
    functable.c
    inftrees.c
    zutil.c
    deflate.c
    deflate_fast.c
    deflate_huff.c
    deflate_medium.c
    deflate_quick.c
    deflate_rle.c
    deflate_slow.c
    deflate_stored.c
    insert_string.c
    insert_string_roll.c
    trees.c
    arch/generic/adler32_c.c
    arch/generic/adler32_fold_c.c
    arch/generic/chunkset_c.c
    arch/generic/compare256_c.c
    arch/generic/crc32_braid_c.c
    arch/generic/crc32_fold_c.c
    arch/generic/slide_hash_c.c
)

set(RAPIDGZIP_ZLIB_NG_SOURCES)
foreach(relative_source IN LISTS RAPIDGZIP_ZLIB_NG_RELATIVE_SOURCES)
    set(absolute_source "${RAPIDGZIP_ZLIB_NG_ROOT}/${relative_source}")
    rapidgzip_require_file("${absolute_source}")
    list(APPEND RAPIDGZIP_ZLIB_NG_SOURCES "${absolute_source}")
endforeach()

foreach(required_file IN ITEMS
        "${RAPIDGZIP_SOURCE_ROOT}/tools/rapidgzip.cpp"
        "${RAPIDGZIP_CXXOPTS_ROOT}/cxxopts.hpp"
        "${RAPIDGZIP_ZLIB_NG_ROOT}/zconf-ng.h.in"
        "${RAPIDGZIP_ZLIB_NG_ROOT}/zconf.h.in"
        "${RAPIDGZIP_ZLIB_NG_ROOT}/zlib.h.in"
        "${RAPIDGZIP_ZLIB_NG_ROOT}/zlib_name_mangling.h.empty"
        "${RAPIDGZIP_ISAL_ROOT}/include/igzip_lib.h"
        "${RAPIDGZIP_RPMALLOC_ROOT}/rpmalloc.c"
        "${RAPIDGZIP_RPMALLOC_ROOT}/rpmalloc.h")
    rapidgzip_require_file("${required_file}")
endforeach()

# Reproduce rapidgzip's manual zlib-ng compatibility target. Upstream writes
# these four files into the zlib-ng source checkout; this harness performs the
# identical transformations exclusively beneath the outer build directory.
set(RAPIDGZIP_ZLIB_NG_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/zlib-ng")
file(MAKE_DIRECTORY "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}")
set(ZLIB_SYMBOL_PREFIX "")
configure_file(
    "${RAPIDGZIP_ZLIB_NG_ROOT}/zconf-ng.h.in"
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zconf-ng.h" @ONLY)
configure_file(
    "${RAPIDGZIP_ZLIB_NG_ROOT}/zconf.h.in"
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zconf.h" @ONLY)
configure_file(
    "${RAPIDGZIP_ZLIB_NG_ROOT}/zlib.h.in"
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zlib.h" @ONLY)
configure_file(
    "${RAPIDGZIP_ZLIB_NG_ROOT}/zlib_name_mangling.h.empty"
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zlib_name_mangling.h" COPYONLY)

rapidgzip_assert_sha256(
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zconf-ng.h"
    "ef5b25e964fc2aff0fccac38e412b4d2e30d105d5ee0bfc63e50eb675794f5c9"
    "Generated zlib-ng zconf-ng.h")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zconf.h"
    "df1730a639dc0efa42fbc81aff55e09e14843a08b61f5fc30affc22b9df3f275"
    "Generated zlib-ng zconf.h")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zlib.h"
    "0f502ab19b9200f6c390945c0fc860816fd0a082e6a01925f7322564f9445565"
    "Generated zlib-ng zlib.h")
rapidgzip_assert_sha256(
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}/zlib_name_mangling.h"
    "38e51a846d6c2bd6100298c55328dba4437c08fa1dceda4eb2e06ecb1d142058"
    "Generated zlib-ng zlib_name_mangling.h")

add_library(zlibstatic STATIC ${RAPIDGZIP_ZLIB_NG_SOURCES})
set_target_properties(zlibstatic PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    LINKER_LANGUAGE C)
target_compile_definitions(zlibstatic PUBLIC ZLIB_COMPAT)
target_include_directories(zlibstatic PRIVATE
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}"
    "${RAPIDGZIP_ZLIB_NG_ROOT}")
target_include_directories(zlibstatic SYSTEM INTERFACE
    "${RAPIDGZIP_ZLIB_NG_GENERATED_DIR}"
    "${RAPIDGZIP_ZLIB_NG_ROOT}")

# Reproduce upstream's rpmalloc target without the parent CMake's incorrect
# submodule-repair fallback. Global new/delete overrides and assertions remain
# disabled exactly as in pinned librapidarchive.
add_library(rpmalloc STATIC "${RAPIDGZIP_RPMALLOC_ROOT}/rpmalloc.c")
set_target_properties(rpmalloc PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    LINKER_LANGUAGE C)
target_compile_definitions(rpmalloc PUBLIC ENABLE_OVERRIDE=0 ENABLE_ASSERTS=0)
target_include_directories(rpmalloc SYSTEM INTERFACE "${RAPIDGZIP_RPMALLOC_ROOT}")

# ISA-L's pinned CMake owns its architecture-specific source selection. Direct
# subdirectory inclusion retains that logic without FetchContent or downloads.
find_program(RAPIDGZIP_NASM_EXECUTABLE NAMES nasm)
if(NOT RAPIDGZIP_NASM_EXECUTABLE)
    message(FATAL_ERROR
        "NASM is required for the pinned ISA-L Linux x86-64 production graph. "
        "Install Debian package 'nasm'; ISA-L will not be silently disabled.")
endif()
set(CMAKE_ASM_NASM_COMPILER "${RAPIDGZIP_NASM_EXECUTABLE}" CACHE FILEPATH
    "NASM compiler required by pinned ISA-L" FORCE)
set(ISAL_BUILD_TESTS OFF CACHE BOOL "Disable ISA-L tests" FORCE)
set(ISAL_BUILD_SHARED_LIBS OFF CACHE BOOL "Build pinned ISA-L statically" FORCE)
set(BUILD_ISAL_SHIM OFF CACHE BOOL "Disable the unused ISA-L shim" FORCE)
add_subdirectory("${RAPIDGZIP_ISAL_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/deps/isa-l")

find_package(Threads REQUIRED)

add_executable(rapidgzip "${RAPIDGZIP_SOURCE_ROOT}/tools/rapidgzip.cpp")
target_compile_features(rapidgzip PRIVATE cxx_std_17)
if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    target_compile_options(rapidgzip PRIVATE -std=c++2c)
endif()
target_compile_definitions(rapidgzip PRIVATE
    LIBRAPIDARCHIVE_WITH_ISAL
    LIBRAPIDARCHIVE_WITH_RPMALLOC)
target_include_directories(rapidgzip PRIVATE "${RAPIDGZIP_SOURCE_ROOT}")
target_include_directories(rapidgzip SYSTEM PRIVATE "${RAPIDGZIP_CXXOPTS_ROOT}")
target_link_libraries(rapidgzip PRIVATE
    rpmalloc
    zlibstatic
    isal
    Threads::Threads)
target_link_options(rapidgzip PRIVATE
    -Wl,-pie,-z,relro,-z,now,-z,defs
    -static-libgcc
    -static-libstdc++)

include(CTest)
if(BUILD_TESTING)
    find_program(RAPIDGZIP_SH_EXECUTABLE NAMES sh REQUIRED)
    find_program(RAPIDGZIP_GZIP_EXECUTABLE NAMES gzip REQUIRED)
    find_program(RAPIDGZIP_CMP_EXECUTABLE NAMES cmp REQUIRED)
    find_program(RAPIDGZIP_GREP_EXECUTABLE NAMES grep REQUIRED)
    find_program(RAPIDGZIP_AWK_EXECUTABLE NAMES awk REQUIRED)
    find_program(RAPIDGZIP_NM_EXECUTABLE NAMES nm REQUIRED)
    find_program(RAPIDGZIP_READELF_EXECUTABLE NAMES readelf REQUIRED)

    add_test(NAME rapidgzip.smoke
        COMMAND "${RAPIDGZIP_SH_EXECUTABLE}"
                "${CMAKE_CURRENT_SOURCE_DIR}/tests/smoke.sh"
                "$<TARGET_FILE:rapidgzip>"
                "${CMAKE_CURRENT_BINARY_DIR}/test-work/smoke"
                "${RAPIDGZIP_GZIP_EXECUTABLE}"
                "${RAPIDGZIP_CMP_EXECUTABLE}"
                "${RAPIDGZIP_GREP_EXECUTABLE}")
    add_test(NAME rapidgzip.binary-inspection
        COMMAND "${RAPIDGZIP_SH_EXECUTABLE}"
                "${CMAKE_CURRENT_SOURCE_DIR}/tests/inspect-binary.sh"
                "$<TARGET_FILE:rapidgzip>"
                "${CMAKE_CURRENT_BINARY_DIR}"
                "${RAPIDGZIP_READELF_EXECUTABLE}"
                "${RAPIDGZIP_NM_EXECUTABLE}"
                "${RAPIDGZIP_GREP_EXECUTABLE}"
                "${RAPIDGZIP_AWK_EXECUTABLE}")
    set_tests_properties(rapidgzip.smoke rapidgzip.binary-inspection PROPERTIES
        ENVIRONMENT "LC_ALL=C")

    add_custom_target(check
        COMMAND "${CMAKE_CTEST_COMMAND}" --output-on-failure
        DEPENDS rapidgzip
        USES_TERMINAL)
endif()
