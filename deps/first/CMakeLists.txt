# First party dependencies -> START
add_subdirectory("ArgsParser")
add_subdirectory("ASMHelper")
add_subdirectory("Constructs")
add_subdirectory("String")
add_subdirectory("DynamicOutput")
add_subdirectory("File")
add_subdirectory("Function")
add_subdirectory("Helpers")
add_subdirectory("IniParser")
add_subdirectory("Input")
add_subdirectory("JSON")
add_subdirectory("LuaMadeSimple")
add_subdirectory("LuaRaw")
add_subdirectory("MProgram")
add_subdirectory("ParserBase")
add_subdirectory("ScopedTimer")
add_subdirectory("SinglePassSigScanner")
# The Unreal (UEPseudo) submodule is pinned to a commit that exists upstream, so that
# `git clone --recursive` works for anyone. Local changes live in patches/ and are replayed here.
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/modules/SubmodulePatches.cmake")
ue4ss_apply_submodule_patch(
    "${CMAKE_CURRENT_SOURCE_DIR}/Unreal"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../patches/UnrealInitializer-peb-walk.patch"
    "src/UnrealInitializer.cpp"
    "PEB module list is cyclic")
ue4ss_apply_submodule_patch(
    "${CMAKE_CURRENT_SOURCE_DIR}/Unreal"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../patches/DetourSubclasses-inplace-short.patch"
    "include/Unreal/Hooks/Internal/DetourSubclasses.hpp"
    "INPLACE_SHORT needs only 12 bytes")

add_subdirectory("Unreal")
add_subdirectory("Profiler")

# Add our Rust components for IDE visibility
if(DEFINED ENABLE_IDE_SOURCE_VISIBILITY AND ENABLE_IDE_SOURCE_VISIBILITY)
    # We only need to include patternsleuth_bind directly for IDE visibility
    # Both patternsleuth and patternsleuth_bind IDE visibility are handled there
    # The actual build is still handled by Corrosion
    #add_subdirectory("patternsleuth_bind")
endif()
# First party dependencies -> END

# Organize generic Rust targets into deps/rust
# Uses organize_targets() from cmake/modules/IDEOrganization.cmake
organize_targets("^cargo-clean$|^cargo-prebuild$" "deps/rust")
