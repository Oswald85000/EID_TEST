cmake_minimum_required(VERSION 3.10)
project(libeid C)
set(CMAKE_C_STANDARD 99)

add_library(eid STATIC libeid.c)
target_include_directories(eid PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(eid_demo libeid.c)
target_compile_definitions(eid_demo PRIVATE EID_DEMO)
target_link_libraries(eid_demo m)

enable_testing()
add_test(NAME run_demo COMMAND eid_demo)
