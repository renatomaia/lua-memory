cmake_minimum_required (VERSION 3.18)
project(LuaMemory C)

option(NULLTERM "Adopt null terminated memory areas?" ON)
option(INSTALL_STATIC_LIB "Install static library?" ON)
option(INSTALL_SHARED_LIB "Install linkable shared library?" OFF)
set(HEADER_DESTINATION include CACHE PATH "Destination of header files.")
set(LIBRARY_DESTINATION lib/LuaMemory CACHE PATH "Destination of linkable libraries.")
set(RUNTIME_DESTINATION bin CACHE PATH "Destination of loadable libraries.")
set(MODULE_DESTINATION lib CACHE PATH "Destination of Lua binary modules.")

add_library(luamem STATIC "src/luamem.c")
add_library(memory SHARED "src/lmemlib.c")

include(GenerateExportHeader)
generate_export_header(memory)

if (NULLTERM)
  add_compile_definitions(LUAMEM_NULLTERM)
endif()

if (NOT LUA_INCLUDE_DIR OR NOT LUA_LIBRARIES)
  find_package(Lua REQUIRED)
endif()
include_directories(PRIVATE ${LUA_INCLUDE_DIR})

install(FILES "src/luamem.h" DESTINATION ${HEADER_DESTINATION})

target_link_libraries(luamem PRIVATE ${LUA_LIBRARIES})
target_link_libraries(memory PRIVATE ${LUA_LIBRARIES} PUBLIC luamem)

if (INSTALL_STATIC_LIB)
  install(TARGETS luamem DESTINATION ${LIBRARY_DESTINATION})
endif()
if (INSTALL_SHARED_LIB)
  install(TARGETS memory ARCHIVE DESTINATION ${LIBRARY_DESTINATION})
endif()
set_target_properties(memory PROPERTIES PREFIX "")
install(TARGETS memory
        RUNTIME DESTINATION ${MODULE_DESTINATION}
        LIBRARY DESTINATION ${MODULE_DESTINATION})
