include_directories(${CMAKE_CURRENT_SOURCE_DIR}/protoGen/)

file(GLOB protoLinkLib "${CMAKE_CURRENT_SOURCE_DIR}/protoGen/*.pb.cc")
file(GLOB exampleSrc "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")


# Add proto generated classes as library
add_library(protoGen STATIC ${protoLinkLib})

# Add files to exclude from examples
set(EXCLUDED_SRC "") # UseProtoExample

# Add executable for each example and target link with protoGen
foreach(exampleSrcFile ${exampleSrc})

    get_filename_component(exampleName ${exampleSrcFile} NAME_WE)

    # Exclude files in exclusion list
    list(FIND EXCLUDED_SRC ${exampleName} INDEX)

    if (NOT ${INDEX} EQUAL -1)
        continue()
    endif()

    message("Adding example source to build: ${exampleName}")

    # Add executable
    add_executable(${exampleName} ${exampleSrcFile})

    # Link with protoGen
    target_link_libraries(${exampleName} protoGen)
    target_include_directories(${exampleName} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/protoGen")
    
endforeach()
