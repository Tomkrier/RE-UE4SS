# Applies local patches to a checked-out git submodule.
#
# Why patches instead of commits:
#   A commit made inside a submodule only exists on the machine that created it unless the
#   submodule has a remote that accepts pushes. Pinning the parent repo to such a commit makes
#   `git clone --recursive` fail for everyone else. Keeping the pin at a commit that exists
#   upstream and replaying the local changes as patch files keeps the fork clonable without
#   needing a fork of the dependency.
#
# The function is idempotent: the patch is skipped when `marker_text` is already present in
# `marker_file`, so re-configuring an already patched tree is a no-op (and a rebuild after a
# clean checkout patches it again).

function(ue4ss_apply_submodule_patch submodule_dir patch_file marker_file marker_text)
    if(NOT EXISTS "${submodule_dir}/${marker_file}")
        message(FATAL_ERROR
            "Submodule file not found: ${submodule_dir}/${marker_file}\n"
            "Initialise submodules first: git submodule update --init --recursive")
    endif()

    file(READ "${submodule_dir}/${marker_file}" content)
    string(FIND "${content}" "${marker_text}" already_applied)
    if(NOT already_applied EQUAL -1)
        return()
    endif()

    find_package(Git QUIET)
    if(NOT GIT_EXECUTABLE)
        message(FATAL_ERROR "git is required to apply ${patch_file}")
    endif()

    execute_process(
        COMMAND "${GIT_EXECUTABLE}" apply --whitespace=nowarn "${patch_file}"
        WORKING_DIRECTORY "${submodule_dir}"
        RESULT_VARIABLE apply_result
        OUTPUT_VARIABLE apply_stdout
        ERROR_VARIABLE apply_stderr)

    if(NOT apply_result EQUAL 0)
        message(FATAL_ERROR "Failed to apply ${patch_file}:\n${apply_stdout}${apply_stderr}")
    endif()

    get_filename_component(patch_name "${patch_file}" NAME)
    message(STATUS "Applied submodule patch: ${patch_name}")
endfunction()
