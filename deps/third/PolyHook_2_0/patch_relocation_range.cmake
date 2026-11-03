# Patches the PolyHook2 trampoline relocation pass.
#
# x64Detour::buildRelocationList() decides whether a rip-relative operand can simply be
# re-encoded ("reloc") or has to go through an absolute-address translation routine.
# Upstream compares the raw block shift (|delta|) against the displacement field width, but the
# value that actually ends up in the instruction is (original_displacement - delta). When the
# original displacement is itself large, the sum overflows disp32 even though |delta| fits, and
# the encoder truncates it silently into a wild address.
#
# Concrete failure (PBZ.exe / UE 5.7, GameModeBase::InitGameState):
#   cmp byte ptr [rip + 0x09E39B02], 0        ; target 0x14DDB12B8
#   delta    = 0xc50ad8e0 - 0x143f777a0 = -0x7EEA9EC0   (|delta| < 2^31 -> "fits")
#   new disp = 0x09E39B02 - delta       =  0x88D039C2   (> 2^31 -> overflows)
#   encoded as 0x88D039C2 -> sign-extended at runtime to 0x4DDB12B8 -> access violation
#   the first time InitGameState runs.
#
# The function below replaces the range check with one based on the re-encoded displacement, so
# overflowing operands are routed through the translation routine (which uses an absolute address
# and is therefore distance independent).
function(ue4ss_patch_polyhook_relocation_range source_directory)
    set(source_file "${source_directory}/sources/ADetour.cpp")

    if(NOT EXISTS "${source_file}")
        message(FATAL_ERROR "PolyHook relocation source not found: ${source_file}")
    endif()

    file(READ "${source_file}" source)

    # Idempotent: bail out if this clone has already been patched.
    string(FIND "${source}" "reencodedDispOutOfRange" already_patched)
    if(NOT already_patched EQUAL -1)
        return()
    endif()

    set(anchor "        // types that change control flow")
    string(FIND "${source}" "${anchor}" anchor_position)
    if(anchor_position EQUAL -1)
        message(FATAL_ERROR "PolyHook relocation source changed; review the rip-relative range patch: ${source_file}")
    endif()

    set(injected [=[        /*
         * ue4ss: the range check must use the displacement that will actually be re-encoded, not the
         * raw block shift (delta).
         *
         * A rip-relative operand keeps pointing at its original absolute target, so once the
         * instruction is moved into the trampoline the new displacement is (original displacement -
         * delta). When the original displacement is itself large, that sum can exceed the disp32
         * field even though |delta| alone still fits, and writeEncoding() then truncates it
         * silently into a wild pointer. Anything that overflows has to be routed through the
         * entry / translation path, which rewrites the access with an absolute address.
         */
        const auto reencodedDispOutOfRange = [&]() -> bool {
            if (!inst.isDisplacementRelative()) {
                return absDelta > maxInstDisp;
            }
            const int64_t reencodedDisp = inst.getDisplacement().Relative - delta;
            const auto maxPositiveDisp = (int64_t) maxInstDisp;
            return reencodedDisp > maxPositiveDisp || reencodedDisp < -maxPositiveDisp - 1;
        };

]=])

    string(REPLACE "${anchor}" "${injected}${anchor}" source "${source}")
    string(REPLACE "if (absDelta > maxInstDisp) {" "if (reencodedDispOutOfRange()) {" source "${source}")

    file(WRITE "${source_file}" "${source}")
    message(STATUS "Patched PolyHook rip-relative relocation range check")
endfunction()
