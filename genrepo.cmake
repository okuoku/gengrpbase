cmake_minimum_required(VERSION 3.20)

macro(submodule repo pth url)
    list(APPEND ${repo}_submodules ${pth})
    set(${repo}_${pth} ${url})
endmacro()

submodule(angle
    build
    https://chromium.googlesource.com/chromium/src/build.git)
submodule(angle
    testing
    https://chromium.googlesource.com/chromium/src/testing)
submodule(angle
    third_party/abseil-cpp
    https://chromium.googlesource.com/chromium/src/third_party/abseil-cpp
    #https://github.com/abseil/abseil-cpp
)
submodule(angle
    third_party/astc-encoder/src
    https://github.com/ARM-software/astc-encoder)
submodule(angle
    third_party/EGL-Registry/src
    https://github.com/KhronosGroup/EGL-Registry)
submodule(angle
    third_party/libdrm/src
    https://chromium.googlesource.com/chromiumos/third_party/libdrm.git)
#submodule(angle
#    third_party/jsoncpp
#    https://chromium.googlesource.com/chromium/src/third_party/jsoncpp)
#submodule(angle ## RECURSIVE??
#    third_party/jsoncpp/source
#    https://github.com/open-source-parsers/jsoncpp)
submodule(angle
    third_party/OpenGL-Registry/src
    https://github.com/KhronosGroup/OpenGL-Registry)
submodule(angle
    third_party/rapidjson/src
    https://github.com/Tencent/rapidjson)
submodule(angle
    third_party/spirv-headers/src
    https://github.com/KhronosGroup/SPIRV-Headers)
submodule(angle
    third_party/spirv-tools/src
    https://github.com/KhronosGroup/SPIRV-Tools)
submodule(angle
    third_party/vulkan-headers/src
    https://github.com/KhronosGroup/Vulkan-Headers)
submodule(angle
    third_party/vulkan-loader/src
    https://github.com/KhronosGroup/Vulkan-Loader)
submodule(angle
    third_party/vulkan-tools/src
    https://github.com/KhronosGroup/Vulkan-Tools)
submodule(angle
    third_party/vulkan_memory_allocator
    https://chromium.googlesource.com/external/github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator
    #https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator
)
submodule(angle
    third_party/zlib
    https://chromium.googlesource.com/chromium/src/third_party/zlib)

set(REPO angle)
set(bare ${CMAKE_CURRENT_LIST_DIR}/${REPO}.git)
set(index ${CMAKE_CURRENT_LIST_DIR}/work)
set(gitmodules ${CMAKE_CURRENT_LIST_DIR}/gitmodules)

# Update repository
execute_process(COMMAND
    git fetch --prune
    WORKING_DIRECTORY ${bare}
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to fetch bare repository")
endif()

# Get the latest refs/heads/main
execute_process(COMMAND
    git show-ref -s refs/heads/main
    OUTPUT_VARIABLE main_ref
    OUTPUT_STRIP_TRAILING_WHITESPACE
    WORKING_DIRECTORY ${bare}

    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to get main ref")
endif()

message(STATUS "ref: ${main_ref}")

# Get gitmodules
execute_process(COMMAND
    git cat-file blob
    ${main_ref}:.gitmodules
    OUTPUT_FILE ${gitmodules}
    WORKING_DIRECTORY ${bare}
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to get .gitmodules")
endif()

# Enumerate existing modules
execute_process(COMMAND
    git config -f ${gitmodules}
    --get-regexp "submodule.*.path"
    OUTPUT_VARIABLE submodule_paths
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to enumerate existing modules")
endif()

string(REPLACE "\n" ";" submodule_paths0 "${submodule_paths}")
set(submodule_paths)
foreach(e IN LISTS submodule_paths0)
    string(STRIP "${e}" e)
    list(APPEND submodule_paths "${e}")
endforeach()
foreach(e IN LISTS submodule_paths)
    if("${e}" MATCHES "submodule.([^.]*).path (.*)")
        set(pth ${CMAKE_MATCH_2})
        if(${REPO}_${pth})
            list(APPEND keep_paths ${pth})
            message(STATUS "Keep: ${pth} => ${${REPO}_${pth}}")
        else()
            list(APPEND remove_paths ${pth})
            message(STATUS "Remove: ${pth}")
        endif()
    else()
        message(STATUS "Ignore [${e}]")
    endif()
endforeach()

# Remove submodule sections
foreach(e IN LISTS remove_paths)
    execute_process(COMMAND
        git config remove-section
        -f ${gitmodules} "submodule.${e}"
        RESULT_VARIABLE rr)
    if(rr)
        message(FATAL_ERROR "Failed to remove section submodule.${e}")
    endif()
endforeach()

# Update Submodule URL
foreach(e IN LISTS keep_paths)
    execute_process(COMMAND
        git config set
        -f ${gitmodules} "submodule.${e}.url" 
        "${${REPO}_${e}}"
        RESULT_VARIABLE rr
    )
    if(rr)
        message(FATAL_ERROR "Failed to update section submodule.${e}")
    endif()
endforeach()

# Create index
set(ENV{GIT_INDEX_FILE} ${index})
set(ENV{GIT_DIR} ${bare})

execute_process(COMMAND
    git hash-object -w -t blob ${gitmodules}
    OUTPUT_VARIABLE hash_gitmodules
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to hash gitmodules")
endif()

message(STATUS ".gitmodules = ${hash_gitmodules}")

execute_process(COMMAND
    git read-tree ${main_ref}
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to create index")
endif()

execute_process(COMMAND
    git update-index --replace 
    --cacheinfo 100644,${hash_gitmodules},.gitmodules
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to inject .gitmodules")
endif()

execute_process(COMMAND
    git rm --cached -f -- ${remove_paths}
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to remove unused submodules")
endif()

execute_process(COMMAND
    git write-tree
    OUTPUT_VARIABLE tree
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to write tree")
endif()

execute_process(COMMAND
    git commit-tree -m TEMP
    -p ${main_ref} ${tree}
    OUTPUT_VARIABLE commit
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE rr)
if(rr)
    message(FATAL_ERROR "Failed to hash gitmodules")
endif()

message(STATUS "commit = ${commit}")

