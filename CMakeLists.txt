cmake_minimum_required (VERSION 3.5)

set(TARGET sotactl)
project(${TARGET})

file(GLOB_RECURSE SRC "src/*.cpp")
set(INCS ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_executable(${TARGET} ${SRC})
target_include_directories(${TARGET} PRIVATE ${INCS})
target_link_libraries(${TARGET} boost_program_options)

target_compile_definitions(${TARGET} PRIVATE BOOST_LOG_DYN_LINK)
target_link_libraries(${TARGET} boost_log boost_filesystem pthread aktualizr_lite aktualizr)
install(TARGETS ${TARGET} RUNTIME DESTINATION bin)

