cmake_minimum_required (VERSION 3.18)
project(LuaMemory)

option(NULLTERM "Adopt null terminated memory areas?" ON)

if(NULLTERM)
  add_compile_definitions(LUAMEM_NULLTERM)
endif()

if(NOT TARGET Lua::Lua)
  if(NOT LUA_INCLUDE_DIR)
    find_package(Lua REQUIRED)
    set(
      LUA_MODULE_DIR "lib/lua/${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}"
      CACHE PATH "Destination of Lua modules."
    )
  elseif(LUA_LIBRARY_DIR AND LUA_LIBRARY_FILE)
    cmake_path(
      APPEND LUA_LIBRARY_DIR "${LUA_LIBRARY_FILE}"
      OUTPUT_VARIABLE LUA_LIBRARIES
    )
  endif()
  add_library(Lua::Lua INTERFACE IMPORTED)
  set_target_properties(
    Lua::Lua
    PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${LUA_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${LUA_LIBRARIES}"
  )
endif()

add_library(luamem "src/luamem.c")
set_target_properties(luamem PROPERTIES PUBLIC_HEADER "src/luamem.h")
target_link_libraries(luamem Lua::Lua)

add_library(memory MODULE "src/lmemlib.c")
target_link_libraries(memory PUBLIC luamem)
set_target_properties(memory PROPERTIES PREFIX "")

include(GenerateExportHeader)
generate_export_header(luamem)
generate_export_header(memory)

install(TARGETS luamem)
if(NOT LUA_MODULE_DIR)
  install(TARGETS memory)
else()
  install(TARGETS memory LIBRARY DESTINATION ${LUA_MODULE_DIR})
endif()
