cmake_minimum_required(VERSION 3.20)
project(VulkanTutorial LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# UTF-8 인코딩 설정 (MSVC)
if(MSVC)
    add_compile_options(/utf-8)
endif()

# 출력 경로 설정 (Debug/Release 모두 bin에)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_CURRENT_SOURCE_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_CURRENT_SOURCE_DIR}/bin)

# Vulkan SDK
find_package(Vulkan REQUIRED)

# GLFW (로컬 라이브러리 사용)
set(GLFW_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Libs/glfw-3.4.bin.WIN64")
set(GLFW_INCLUDE_DIR "${GLFW_DIR}/include")
set(GLFW_LIBRARY "${GLFW_DIR}/lib-vc2022/glfw3.lib")

# GLM (헤더 전용)
set(GLM_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Libs/glm")

# 실행 파일
add_executable(Tutorial Tutorial/main.cpp)

# Include 경로
target_include_directories(Tutorial PRIVATE
    ${Vulkan_INCLUDE_DIRS}
    ${GLFW_INCLUDE_DIR}
    ${GLM_INCLUDE_DIR}
)

# 링크 라이브러리
target_link_libraries(Tutorial PRIVATE
    ${Vulkan_LIBRARIES}
    ${GLFW_LIBRARY}
)

# 셰이더 컴파일 (빌드 후 bin/shaders 폴더에 생성)
find_program(GLSLC glslc HINTS "$ENV{VULKAN_SDK}/Bin")

if(GLSLC)
    set(SHADER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shaders")
    set(OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bin/shaders")
    
    add_custom_command(TARGET Tutorial POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
        COMMAND ${GLSLC} ${SHADER_DIR}/shader.vert -o ${OUTPUT_DIR}/vert.spv
        COMMAND ${GLSLC} ${SHADER_DIR}/shader.frag -o ${OUTPUT_DIR}/frag.spv
        COMMENT "Compiling shaders to bin/shaders..."
    )
endif()

