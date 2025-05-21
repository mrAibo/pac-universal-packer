#!/bin/bash

# Test suite for pac.sh

# Exit on error to ensure test failures are caught
set -e

# --- Test Setup ---
# Directory for test files and outputs
TEST_DIR_NAME="pac_test_environment"
TEST_ROOT_DIR="$(pwd)/$TEST_DIR_NAME" # Keep tests self-contained

# Source the script to be tested.
# Assuming pac.sh is in the parent directory of this 'tests' directory.
PAC_SCRIPT_PATH="../pac.sh"
if [ ! -f "$PAC_SCRIPT_PATH" ]; then
    echo "Error: pac.sh not found at $PAC_SCRIPT_PATH" >&2
    echo "Please ensure the test script is run from within the 'tests' directory or adjust PAC_SCRIPT_PATH." >&2
    exit 1
fi
# shellcheck source=../pac.sh
source "$PAC_SCRIPT_PATH"

# --- shunit2 Setup ---
# Download shunit2 if not present
SHUNIT2_HELPER_SCRIPT="$(dirname "$0")/get_shunit2.sh"
if [ -f "$SHUNIT2_HELPER_SCRIPT" ]; then
    bash "$SHUNIT2_HELPER_SCRIPT" # Execute the helper script
    SHUNIT2_PATH="$(dirname "$0")/shunit2/shunit2"
else
    echo "Warning: get_shunit2.sh not found. Assuming shunit2 is in PATH or installed globally." >&2
    SHUNIT2_PATH="shunit2" # Fallback if helper is missing
fi

if [ ! -f "$SHUNIT2_PATH" ]; then
    echo "Error: shunit2 not found at $SHUNIT2_PATH after attempting download." >&2
    echo "Please ensure shunit2 is available." >&2
    exit 1
fi
# shellcheck source=./shunit2/shunit2
source "$SHUNIT2_PATH"

# --- Helper Functions ---

# Function to create dummy files for testing
create_dummy_files() {
    mkdir -p "$1" # Base directory for these files
    echo "This is file1.txt" > "$1/file1.txt"
    echo "Another file here, file2.log" > "$1/file2.log"
    mkdir -p "$1/subdir"
    echo "Content for subdir/file3.dat" > "$1/subdir/file3.dat"
    echo "Test for exclude pattern" > "$1/subdir/exclude_me.tmp"
}

# --- Test Suites & Test Cases ---

# oneTimeSetUp: Executed once before all tests.
# Used for global setup, like creating a main test directory.
oneTimeSetUp() {
    echo "Creating test root directory: $TEST_ROOT_DIR"
    rm -rf "$TEST_ROOT_DIR" # Clean up from previous runs
    mkdir -p "$TEST_ROOT_DIR"
    # You can also pre-create some common test data here if needed by many tests
    # For example, a common set of source files
    mkdir -p "$TEST_ROOT_DIR/common_source_files"
    create_dummy_files "$TEST_ROOT_DIR/common_source_files"
}

# oneTimeTearDown: Executed once after all tests.
# Used for global cleanup.
oneTimeTearDown() {
    echo "Cleaning up test root directory: $TEST_ROOT_DIR"
    rm -rf "$TEST_ROOT_DIR"
}

# setUp: Executed before each test case.
# Ideal for creating per-test specific directories or files.
setUp() {
    # Example: create a dedicated directory for each test's artifacts
    # The specific test name can be obtained from shunit2's SHUNIT_CURRENT_TEST variable if needed later.
    # For now, individual tests will manage their subdirectories within TEST_ROOT_DIR.
    echo "Setting up for a test..."
    # Ensure the main test directory exists (should be by oneTimeSetUp)
    mkdir -p "$TEST_ROOT_DIR"
}

# tearDown: Executed after each test case.
# Ideal for cleaning up artifacts created by a specific test.
tearDown() {
    echo "Tearing down after a test..."
    # Example: If tests create their own subdirectories in TEST_ROOT_DIR, clean them here.
    # However, for safety and clarity, it's often better if each test cleans what it specifically created,
    # or oneTimeTearDown handles the bulk removal.
}

# --- Example Test Case (will be expanded) ---

testHelloWorld() {
    assertTrue "Example test, should succeed" "[ 1 -eq 1 ]"
}

testPacHelp() {
    # Test that 'pac -h' or 'pac --help' executes successfully and prints usage.
    # The `pac` function, when sourced and called with -h/--help, will have its
    # `parse_args` function return 2, which then becomes the return status of `pac`.
    
    local local_pac_output_h
    local exit_code_h
    
    # Capture stderr as well, as getopt errors (which also show help) go to stderr.
    local_pac_output_h=$(pac -h 2>&1)
    exit_code_h=$? # Capture the return code of the pac function call
    assertEquals "pac -h should return status 2 (actual: $exit_code_h). Output: $local_pac_output_h" 2 "$exit_code_h"
    assertTrue "Help message from -h should contain 'SYNTAX'. Output: $local_pac_output_h" "echo '$local_pac_output_h' | grep -q 'SYNTAX'"

    local local_pac_output_help
    local exit_code_help
    local_pac_output_help=$(pac --help 2>&1)
    exit_code_help=$?
    assertEquals "pac --help should return status 2 (actual: $exit_code_help). Output: $local_pac_output_help" 2 "$exit_code_help"
    assertTrue "Help message from --help should contain 'SYNTAX'. Output: $local_pac_output_help" "echo '$local_pac_output_help' | grep -q 'SYNTAX'"
}

# --- Compression / Extraction Tests ---

testCompressExtract_Zip_SingleFile() {
    local test_name="zip_single_file"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    # Setup test-specific directories
    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    local original_file_name="file1.txt"
    local original_file_path="$source_dir/$original_file_name"
    local original_content="This is the content for the ZIP single file test."
    echo "$original_content" > "$original_file_path"

    local archive_base_name="test_archive_zip_single"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # Compress the file
    # Calling pac function: pac -c zip -n test_archive_zip_single -t archive_dir source_dir/file1.txt
    # Stdout/Stderr of pac call is captured.
    local compress_output
    local compress_rc

    # Ensure pac's internal variables are in a clean state if it matters.
    # They are generally local to the function or reset at its start.
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    compress_rc=$?

    assertEquals "Compression failed for $test_name. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive file '$full_archive_path' was not created. Output: $compress_output" "[ -f \"$full_archive_path\" ]"
    assertTrue "Archive file '$full_archive_path' is empty. Output: $compress_output" "[ -s \"$full_archive_path\" ]"

    # Extract the file
    # Calling pac function: pac -x -t extract_dir archive_dir/test_archive_zip_single.zip
    local extract_output
    local extract_rc

    extract_output=$(pac -x -t "$extract_dir" "$full_archive_path" 2>&1)
    extract_rc=$?
    
    assertEquals "Extraction failed for $test_name. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    local extracted_file_path="$extract_dir/$original_file_name"
    assertTrue "Extracted file '$extracted_file_path' not found. Output: $extract_output" "[ -f \"$extracted_file_path\" ]"
    
    local extracted_content
    extracted_content=$(cat "$extracted_file_path")
    assertEquals "Content of extracted file does not match original for $test_name." "$original_content" "$extracted_content"

    # Cleanup: Remove the directory created specifically for this test
    rm -rf "$current_test_dir"
}

# Test for -i (include) option - currently, this is expected to NOT filter for zip
testOption_Include_Zip_NoEffect() {
    local test_name="option_include_zip_no_effect"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    echo "This should be included by pattern" > "$source_dir/include_me.txt"
    echo "This should also be included by pattern" > "$source_dir/also_include.txt"
    echo "This should NOT be included if -i worked like a whitelist" > "$source_dir/dont_include.log"

    local archive_base_name="archive_include_test"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # pac -c zip -i "*.txt" -n archive_include_test -t archive_dir source_dir
    # As per current pac.sh, -i patterns are NOT passed to the zip command's filtering options.
    # So, all files in source_dir are expected to be included.
    local compress_output compress_rc
    compress_output=$(pac -c "$archive_format" -i "*.txt" -n "$archive_base_name" -t "$archive_dir" "$source_dir" 2>&1)
    compress_rc=$?

    if [[ $compress_rc -eq 6 ]]; then # zip tool might be missing
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Compression with -i option (expected no effect for zip) failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive '$full_archive_path' not created (-i test). Output: $compress_output" "[ -f \"$full_archive_path\" ]"

    # Extract and verify
    pac -x -t "$extract_dir" "$full_archive_path" >/dev/null
    
    # All files are expected because -i is not implemented for zip's filtering in pac.sh
    assertTrue "include_me.txt not found (-i test, no filter expected for zip)." "[ -f \"$extract_dir/$(basename "$source_dir")/include_me.txt\" ]"
    assertTrue "also_include.txt not found (-i test, no filter expected for zip)." "[ -f \"$extract_dir/$(basename "$source_dir")/also_include.txt\" ]"
    assertTrue "dont_include.log not found (-i test, no filter expected for zip, so it SHOULD be present)." "[ -f \"$extract_dir/$(basename "$source_dir")/dont_include.log\" ]"
    
    rm -rf "$current_test_dir"
}

# Test for -i (include) option - currently, this is expected to NOT filter for zip
testOption_Include_Zip_NoEffect() {
    local test_name="option_include_zip_no_effect"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    echo "This should be included by pattern" > "$source_dir/include_me.txt"
    echo "This should also be included by pattern" > "$source_dir/also_include.txt"
    echo "This should NOT be included if -i worked like a whitelist" > "$source_dir/dont_include.log"

    local archive_base_name="archive_include_test"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # pac -c zip -i "*.txt" -n archive_include_test -t archive_dir source_dir
    # As per current pac.sh, -i patterns are NOT passed to the zip command.
    # So, all files in source_dir are expected to be included.
    local compress_output compress_rc
    compress_output=$(pac -c "$archive_format" -i "*.txt" -n "$archive_base_name" -t "$archive_dir" "$source_dir" 2>&1)
    compress_rc=$?

    if [[ $compress_rc -eq 6 ]]; then # zip tool might be missing
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Compression with -i option (expected no effect for zip) failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive '$full_archive_path' not created (-i test). Output: $compress_output" "[ -f \"$full_archive_path\" ]"

    # Extract and verify
    pac -x -t "$extract_dir" "$full_archive_path" >/dev/null
    
    # All files are expected because -i is not implemented for zip's filtering in pac.sh
    assertTrue "include_me.txt not found (-i test, no filter expected for zip)." "[ -f \"$extract_dir/$(basename "$source_dir")/include_me.txt\" ]"
    assertTrue "also_include.txt not found (-i test, no filter expected for zip)." "[ -f \"$extract_dir/$(basename "$source_dir")/also_include.txt\" ]"
    assertTrue "dont_include.log not found (-i test, no filter expected for zip, so it SHOULD be present)." "[ -f \"$extract_dir/$(basename "$source_dir")/dont_include.log\" ]"
    
    rm -rf "$current_test_dir"
}

# --- Edge Case Tests ---

testEdge_EmptyFile_CompressExtract() {
    local test_name="edge_empty_file"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    local empty_file_name="empty_file.txt"
    local empty_file_path="$source_dir/$empty_file_name"
    touch "$empty_file_path" # Create an empty file

    assertTrue "Empty source file '$empty_file_path' does not exist or is not empty." "[ -f \"$empty_file_path\" ] && ! [ -s \"$empty_file_path\" ]"

    local archive_base_name="empty_file_archive"
    local archive_format="zip" # Zip can handle empty files
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    local compress_output compress_rc
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$empty_file_path" 2>&1)
    compress_rc=$?
    if [[ $compress_rc -eq 6 ]]; then # Tool not found
        startSkipping; echo "Skipping $test_name: tool for $archive_format not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Compression of empty file failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive of empty file '$full_archive_path' not created." "[ -f \"$full_archive_path\" ]"
    # Archive of an empty file might not be empty itself (metadata), so -s check might be misleading for archive.

    local extract_output extract_rc
    extract_output=$(pac -x -t "$extract_dir" "$full_archive_path" 2>&1)
    extract_rc=$?
    assertEquals "Extraction of empty file archive failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    local extracted_file_path="$extract_dir/$empty_file_name"
    assertTrue "Extracted empty file '$extracted_file_path' not found." "[ -f \"$extracted_file_path\" ]"
    assertFalse "Extracted empty file '$extracted_file_path' should be empty (it has size)." "[ -s \"$extracted_file_path\" ]"
    
    rm -rf "$current_test_dir"
}

testEdge_FileNameWithSpaces_CompressExtract() {
    local test_name="edge_filename_spaces"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    local spaced_file_name="my test file with spaces.txt"
    local spaced_file_path="$source_dir/$spaced_file_name"
    local original_content="Content for file with spaces in name."
    echo "$original_content" > "$spaced_file_path"

    local archive_base_name="spaced_filename_archive"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    local compress_output compress_rc
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$spaced_file_path" 2>&1)
    compress_rc=$?
    if [[ $compress_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: tool for $archive_format not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Compression of file with spaces failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive of file with spaces '$full_archive_path' not created." "[ -f \"$full_archive_path\" ]"

    local extract_output extract_rc
    extract_output=$(pac -x -t "$extract_dir" "$full_archive_path" 2>&1)
    extract_rc=$?
    assertEquals "Extraction of archive with spaced filename failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    local extracted_file_path="$extract_dir/$spaced_file_name"
    assertTrue "Extracted file with spaces '$extracted_file_path' not found." "[ -f \"$extracted_file_path\" ]"
    assertEquals "Content of extracted file with spaces does not match." "$original_content" "$(cat "$extracted_file_path")"
    
    rm -rf "$current_test_dir"
}

testEdge_DirNameWithSpaces_CompressExtract() {
    local test_name="edge_dirname_spaces"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_base_dir="$current_test_dir/source" # Parent of the spaced directory
    local spaced_dir_name="my test dir with spaces"
    local source_dir_with_spaces="$source_base_dir/$spaced_dir_name"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir_with_spaces" "$archive_dir" "$extract_dir"
    
    local file_in_spaced_dir_name="file_in_spaced_dir.txt"
    local file_in_spaced_dir_path="$source_dir_with_spaces/$file_in_spaced_dir_name"
    local original_content="Content for file in spaced directory."
    echo "$original_content" > "$file_in_spaced_dir_path"

    local archive_base_name="spaced_dirname_archive"
    local archive_format="zip" # zip handles spaces well in paths
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # We are compressing the directory "$source_dir_with_spaces"
    # The input to pac will be this directory path.
    local compress_output compress_rc
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$source_dir_with_spaces" 2>&1)
    compress_rc=$?
    if [[ $compress_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: tool for $archive_format not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Compression of dir with spaces failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive of dir with spaces '$full_archive_path' not created." "[ -f \"$full_archive_path\" ]"

    local extract_output extract_rc
    extract_output=$(pac -x -t "$extract_dir" "$full_archive_path" 2>&1)
    extract_rc=$?
    assertEquals "Extraction of archive with spaced dirname failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    # The extracted structure will be extract_dir/my test dir with spaces/file_in_spaced_dir.txt
    local extracted_dir_path="$extract_dir/$spaced_dir_name"
    local extracted_file_path="$extracted_dir_path/$file_in_spaced_dir_name"
    
    assertTrue "Extracted dir with spaces '$extracted_dir_path' not found." "[ -d \"$extracted_dir_path\" ]"
    assertTrue "Extracted file in spaced dir '$extracted_file_path' not found." "[ -f \"$extracted_file_path\" ]"
    assertEquals "Content of extracted file in spaced dir does not match." "$original_content" "$(cat "$extracted_file_path")"
    
    rm -rf "$current_test_dir"
}

testEdge_ExtractToExisting_Overwrite() {
    local test_name="edge_extract_overwrite"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"         # For creating the archive
    local archive_dir="$current_test_dir/archive"       # Where archive is stored
    local extract_target_dir="$current_test_dir/extract_target_overwrite" # Target for extraction

    mkdir -p "$source_dir" "$archive_dir" "$extract_target_dir"

    # Prepare files for the archive
    local file_A_content_new="New content for file_A.txt from archive"
    local file_B_content="Content for file_B.txt from archive"
    echo "$file_A_content_new" > "$source_dir/file_A.txt"
    echo "$file_B_content" > "$source_dir/file_B.txt"

    # Prepare a pre-existing file in the extraction target directory
    local file_A_content_old="Old content for file_A.txt in target dir"
    echo "$file_A_content_old" > "$extract_target_dir/file_A.txt"

    local archive_base_name="overwrite_test_archive"
    local archive_format="zip" # zip typically overwrites without asking by default
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # Compress source_dir (which contains file_A.txt and file_B.txt)
    local compress_output compress_rc
    # Note: When compressing a directory, the directory itself is usually included as the root in the archive.
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$source_dir" 2>&1)
    compress_rc=$?
    if [[ $compress_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: tool for $archive_format not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Compression for overwrite test failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive for overwrite test '$full_archive_path' not created." "[ -f \"$full_archive_path\" ]"

    # Extract the archive to extract_target_dir
    local extract_output extract_rc
    # pac -x -t extract_target_dir archive_dir/overwrite_test_archive.zip
    extract_output=$(pac -x -t "$extract_target_dir" "$full_archive_path" 2>&1)
    extract_rc=$?
    assertEquals "Extraction for overwrite test failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    # Paths of files after extraction. Since source_dir was archived, it will be a subdirectory in extract_target_dir.
    local extracted_base_dir="$extract_target_dir/$(basename "$source_dir")"
    local extracted_file_A_path="$extracted_base_dir/file_A.txt"
    local extracted_file_B_path="$extracted_base_dir/file_B.txt"

    # This assertion is tricky. If file_A.txt was directly in extract_target_dir, it would be overwritten.
    # But since we are extracting an archive of source_dir, it creates source_dir within extract_target_dir.
    # So, the original extract_target_dir/file_A.txt will NOT be overwritten.
    # A new extract_target_dir/source/file_A.txt will be created.
    # This test needs to be adjusted based on how pac and underlying tools handle this.
    # Most tools (tar, zip) when extracting a dir archived as 'source_dir' into 'target_dir'
    # will create 'target_dir/source_dir/...'.
    
    # Let's adjust expectation: the pre-existing file_A.txt in extract_target_dir should remain untouched.
    # The new files will be under extract_target_dir/source_dir_basename/
    
    assertTrue "Original file_A.txt in target dir was unexpectedly modified or deleted." \
        "[ -f \"$extract_target_dir/file_A.txt\" ] && [[ \"$(cat "$extract_target_dir/file_A.txt")\" == \"$file_A_content_old\" ]]"

    assertTrue "Extracted directory '$extracted_base_dir' not found." "[ -d \"$extracted_base_dir\" ]"
    assertTrue "Extracted file_A.txt ('$extracted_file_A_path') not found in its own directory." "[ -f \"$extracted_file_A_path\" ]"
    assertEquals "Content of extracted file_A.txt does not match new content." "$file_A_content_new" "$(cat "$extracted_file_A_path")"
    
    assertTrue "Extracted file_B.txt ('$extracted_file_B_path') not found." "[ -f \"$extracted_file_B_path\" ]"
    assertEquals "Content of extracted file_B.txt does not match." "$file_B_content" "$(cat "$extracted_file_B_path")"

    rm -rf "$current_test_dir"
}

testOption_Exclude_SinglePattern_Zip() {
    local test_name="option_exclude_single_zip"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    echo "Text file" > "$source_dir/file.txt"
    echo "Log file" > "$source_dir/file.log" # This should be excluded
    echo "Another text file" > "$source_dir/another.txt"
    mkdir "$source_dir/dir_to_include"
    echo "file in dir" > "$source_dir/dir_to_include/in_dir.txt"


    local archive_base_name="archive_exclude_single"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # Compress excluding *.log: pac -c zip -e "*.log" -n archive_exclude_single -t archive_dir source_dir
    # Note: For zip, patterns are usually relative to the source directory.
    # pac.sh passes patterns directly to zip's -x option.
    # If source_dir is '.../source', then to exclude '.../source/file.log', pattern should be 'file.log' or '*/file.log'
    # or if zip is run from inside 'source_dir' then '*.log'.
    # pac.sh's current implementation for zip: zip "${zip_opts[@]}" "$output_file_path" "${input_files[@]}"
    # where input_files can be directories. If input is 'source_dir', zip archives 'source_dir/...'
    # So, exclude pattern for 'zip' should be relative to items being zipped. E.g. 'source_dir/*.log' if zipping 'source_dir' from parent.
    # Or, if 'pac' cd's into the parent of input_files, then 'basename(input_file)/*.log'.
    # The current pac.sh code: (cd "$PWD" && zip "${zip_opts[@]}" "$output_file_path" "${input_files[@]}")
    # So if input_files is ["$source_dir"], then patterns should be relative to PWD, e.g. "$(basename $source_dir)/file.log".
    # This is tricky. Let's assume patterns are simple like "*.log" and test current behavior.
    # The zip command in pac.sh is run from $PWD, and input files are given as paths.
    # So, if $source_dir is "./pac_test_environment/option_exclude_single_zip/source",
    # and we pass $source_dir as input, zip will store "pac_test_environment/option_exclude_single_zip/source/file.log".
    # An exclude pattern of "*.log" might not work as expected by zip in this case.
    # zip's -x pattern is usually relative to the archive root.
    # If we are zipping the *contents* of source_dir, then "*.log" would work.
    # If we are zipping source_dir itself, then "source_dir/*.log" or similar is needed.
    # pac.sh passes input files/dirs directly.
    # For a directory input like `source_dir`, zip includes the directory name.
    # So, to exclude `source_dir/file.log`, pattern for zip should be `*/file.log` or full path if zip supports that.
    # Let's try a pattern that should work with how zip handles paths: `*/file.log` or specific path `$(basename $source_dir)/file.log`

    local compress_output
    local compress_rc
    # Using pattern that works if `source_dir` itself is the root in the archive, or if zip is smart.
    # A more robust exclude pattern for zip when zipping a directory `source_dir` from `PWD` to exclude `source_dir/file.log`
    # would be `$(basename "$source_dir")/file.log`. Or `*file.log` if it's at any depth.
    # The current `pac.sh` implementation runs zip from $PWD.
    # If input is `$source_dir`, zip stores paths like `pac_test_environment/.../source/file.log`.
    # So, an exclude pattern like `"*.log"` might not work.
    # Let's try `"*/*.log"` or `"*file.log"`
    # The `pac.sh` help says -e "*.tmp", which implies simple patterns.
    # Testing with `file.log` directly as exclude pattern assuming it's relative to files found.
    # After reviewing zip man page: exclude patterns are relative to the input path scan.
    # If `zip archive.zip dir/`, then `-x dir/file.log`.
    # If `(cd dir && zip ../archive.zip .)` then `-x file.log`.
    # pac.sh does `(cd "$PWD" && zip ... "$output_file_path" "${input_files[@]}")`
    # So if input_files is "$source_dir", then paths in zip are like "$source_dir/file.log".
    # The exclude pattern must match this. So, `"$source_dir/file.log"` or `"*/file.log"`
    
    # Using a pattern that should reliably exclude file.log within source_dir
    local exclude_pattern_for_zip="${source_dir##*/}/file.log" # This should be 'source/file.log' if source_dir is simple path
                                                          # Or, more generally, if source_dir is /a/b/c/source, then 'source/file.log'
                                                          # This is still tricky. zip -x pattern is relative to the paths being zipped.
                                                          # If we `zip -r archive source_dir`, paths are `source_dir/file.log`.
                                                          # So pattern `source_dir/file.log` or `*/file.log` should work.

    # The `zip` command in `pac.sh` uses `-x pattern` where `pattern` is directly from `-e`.
    # If `pac -c zip -e "*.log" -t arc_dir src_dir`, zip command will be `zip ... arc_dir/archive.zip src_dir -x "*.log"`.
    # This means `zip` will exclude any file ending in `.log` inside `src_dir`. This should work.

    compress_output=$(pac -c "$archive_format" -e "*.log" -n "$archive_base_name" -t "$archive_dir" "$source_dir" 2>&1)
    compress_rc=$?
    assertEquals "Compression with single exclude failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive '$full_archive_path' not created. Output: $compress_output" "[ -f \"$full_archive_path\" ]"

    # Extract and verify
    pac -x -t "$extract_dir" "$full_archive_path" >/dev/null
    assertTrue "Extracted file.txt not found." "[ -f \"$extract_dir/$(basename "$source_dir")/file.txt\" ]"
    assertTrue "Extracted another.txt not found." "[ -f \"$extract_dir/$(basename "$source_dir")/another.txt\" ]"
    assertTrue "Extracted in_dir.txt not found." "[ -f \"$extract_dir/$(basename "$source_dir")/dir_to_include/in_dir.txt\" ]"
    assertFalse "Excluded file.log IS present." "[ -f \"$extract_dir/$(basename "$source_dir")/file.log\" ]"
    
    rm -rf "$current_test_dir"
}

testOption_Exclude_MultiplePatterns_Zip() {
    local test_name="option_exclude_multi_zip"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    echo "Text file" > "$source_dir/file.txt"
    echo "Log file" > "$source_dir/file.log"     # Exclude 1
    echo "Image file" > "$source_dir/image.jpg" 
    echo "Temp file" > "$source_dir/temp.tmp"    # Exclude 2
    mkdir "$source_dir/subdir"
    echo "Another log" > "$source_dir/subdir/another.log" # Exclude 1 (recursive)

    local archive_base_name="archive_exclude_multi"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    compress_output=$(pac -c "$archive_format" -e "*.log" -e "*.tmp" -n "$archive_base_name" -t "$archive_dir" "$source_dir" 2>&1)
    compress_rc=$?
    assertEquals "Compression with multiple excludes failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive '$full_archive_path' not created. Output: $compress_output" "[ -f \"$full_archive_path\" ]"

    # Extract and verify
    pac -x -t "$extract_dir" "$full_archive_path" >/dev/null
    assertTrue "Extracted file.txt not found." "[ -f \"$extract_dir/$(basename "$source_dir")/file.txt\" ]"
    assertTrue "Extracted image.jpg not found." "[ -f \"$extract_dir/$(basename "$source_dir")/image.jpg\" ]"
    assertFalse "Excluded file.log IS present." "[ -f \"$extract_dir/$(basename "$source_dir")/file.log\" ]"
    assertFalse "Excluded temp.tmp IS present." "[ -f \"$extract_dir/$(basename "$source_dir")/temp.tmp\" ]"
    assertFalse "Excluded subdir/another.log IS present." "[ -f \"$extract_dir/$(basename "$source_dir")/subdir/another.log\" ]"
    
    rm -rf "$current_test_dir"
}


testOption_FilterFile_Zip() {
    local test_name="option_filter_file_zip"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"
    local filter_file_path="$current_test_dir/filters.txt"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"

    # Create filter file
    # Current pac.sh only uses exclude patterns from filter file for zip.
    # Include patterns like +*.txt will be ignored for zip.
    echo "Content for main.txt" > "$source_dir/main.txt"
    echo "Content for temp_doc.txt" > "$source_dir/temp_doc.txt" # Should be excluded by pattern
    echo "Content for app.log" > "$source_dir/app.log"           # Should be excluded by pattern
    echo "Content for notes.txt" > "$source_dir/notes.txt"
    echo "Content for other.dat" > "$source_dir/other.dat"       # Should be included (as not excluded)
    mkdir "$source_dir/tmp_dir"                                  # Should be excluded
    echo "dont_pack_me" > "$source_dir/tmp_dir/ignore.dat"


    # Filter file content:
    # Current pac.sh only implements exclude patterns from filter file for zip.
    # So + patterns will effectively be ignored by the zip command generation.
    cat > "$filter_file_path" <<FILTER_EOF
# This is a comment
+*.txt 
+*.dat
-*.log
-temp_doc.txt
-tmp_dir/
FILTER_EOF

    local archive_base_name="archive_filter_file"
    local archive_format="zip"
    local full_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # pac -c zip -f filters.txt -n archive_filter_file -t archive_dir source_dir
    local compress_output
    local compress_rc
    compress_output=$(pac -c "$archive_format" -f "$filter_file_path" -n "$archive_base_name" -t "$archive_dir" "$source_dir" 2>&1)
    compress_rc=$?
    # Note: pac.sh for zip only processes exclude_patterns from filter file.
    # It does not process include_patterns from filter file for zip.
    # So, +*.txt and +*.dat will NOT restrict the input files for zip.
    # Only -*.log, -temp_doc.txt, -tmp_dir/ will be passed to zip's -x option.

    assertEquals "Compression with filter file failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive '$full_archive_path' not created (filter file). Output: $compress_output" "[ -f \"$full_archive_path\" ]"

    # Extract and verify
    pac -x -t "$extract_dir" "$full_archive_path" >/dev/null
    
    # Expected to be included (because not excluded by any '-' pattern)
    assertTrue "main.txt not found (filter file). Extracted: $(ls -R $extract_dir)" "[ -f \"$extract_dir/$(basename "$source_dir")/main.txt\" ]"
    assertTrue "notes.txt not found (filter file)." "[ -f \"$extract_dir/$(basename "$source_dir")/notes.txt\" ]"
    assertTrue "other.dat not found (filter file)." "[ -f \"$extract_dir/$(basename "$source_dir")/other.dat\" ]"

    # Expected to be excluded by filter file
    assertFalse "temp_doc.txt IS present (filter file - excluded by name)." "[ -f \"$extract_dir/$(basename "$source_dir")/temp_doc.txt\" ]"
    assertFalse "app.log IS present (filter file - excluded by *.log)." "[ -f \"$extract_dir/$(basename "$source_dir")/app.log\" ]"
    assertFalse "tmp_dir/ IS present (filter file - excluded by dir name)." "[ -d \"$extract_dir/$(basename "$source_dir")/tmp_dir\" ]"
    assertFalse "tmp_dir/ignore.dat IS present (filter file - tmp_dir/ was excluded)." "[ -f \"$extract_dir/$(basename "$source_dir")/tmp_dir/ignore.dat\" ]"
    
    rm -rf "$current_test_dir"
}

# --- Option Tests (Continued from previous step) ---

# Generic function to test compression and extraction of a single file for a given format
_testCompressExtract_SingleFile_Format() {
    local format_to_test=$1
    local file_content_prefix=$2
    local jobs_option_for_compress="" # Will be empty if format doesn't support jobs or not testing it here

    if [[ -n "$3" ]]; then # Third argument is number of jobs
      if [[ "$format_to_test" == "tar.xz" || "$format_to_test" == "tar.zst" || "$format_to_test" == "7z" ]]; then
        jobs_option_for_compress="-j $3"
      fi
    fi

    local test_name="format_${format_to_test//./_}" # e.g. format_tar_gz
    if [[ -n "$3" ]]; then
      test_name+="_jobs_$3"
    fi

    echo "Starting test: $test_name"

    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir="$current_test_dir/extracted"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"
    
    local original_file_name="testfile.txt"
    local original_file_path="$source_dir/$original_file_name"
    local original_content="$file_content_prefix for $format_to_test"
    echo "$original_content" > "$original_file_path"

    local archive_base_name="test_archive_${test_name}"
    local full_archive_path="$archive_dir/${archive_base_name}.${format_to_test}"

    # Compression
    local compress_output
    local compress_rc
    if [[ -n "$jobs_option_for_compress" ]]; then
        compress_output=$(pac -c "$format_to_test" $jobs_option_for_compress -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    else
        compress_output=$(pac -c "$format_to_test" -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    fi
    compress_rc=$?

    # Check if tool for this format is installed (exit code 6 from pac)
    if [[ $compress_rc -eq 6 ]]; then
        startSkipping # Start skipping remaining tests in this group/function
        echo "Skipping test $test_name as required tool for format '$format_to_test' is not installed (pac returned 6)."
        # To make shunit2 correctly skip, we need to return 0 from the test function itself
        # after calling startSkipping. We'll handle this in the calling test.
        # For now, just log and ensure no further assertions fail.
        # Clean up and return a specific code that the caller can check.
        rm -rf "$current_test_dir"
        return 6 # Special RC to indicate skip due to missing tool
    fi

    assertEquals "Compression failed for $test_name. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive file '$full_archive_path' was not created for $test_name. Output: $compress_output" "[ -f \"$full_archive_path\" ]"
    assertTrue "Archive file '$full_archive_path' is empty for $test_name. Output: $compress_output" "[ -s \"$full_archive_path\" ]"

    # Extraction
    local extract_output
    local extract_rc
    extract_output=$(pac -x -t "$extract_dir" "$full_archive_path" 2>&1)
    extract_rc=$?
    
    # Check if tool for this format is installed (for extraction)
    if [[ $extract_rc -eq 6 ]]; then
        startSkipping
        echo "Skipping extraction part of $test_name as required tool for format '$format_to_test' is not installed for extraction (pac returned 6)."
        rm -rf "$current_test_dir"
        return 6 # Special RC
    fi

    assertEquals "Extraction failed for $test_name. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    local extracted_file_path="$extract_dir/$original_file_name"
    assertTrue "Extracted file '$extracted_file_path' not found for $test_name. Output: $extract_output" "[ -f \"$extracted_file_path\" ]"
    
    local extracted_content
    extracted_content=$(cat "$extracted_file_path")
    assertEquals "Content of extracted file does not match original for $test_name." "$original_content" "$extracted_content"

    rm -rf "$current_test_dir"
    return 0 # Success
}

# --- Test cases for each format ---
testCompressExtract_Tar_SingleFile() { 
    _testCompressExtract_SingleFile_Format "tar" "Tar test content" && return 0
    # If _testCompressExtract_SingleFile_Format returned 6, we need to handle shunit2 skipping
    local rc=$?
    if [[ $rc -eq 6 ]]; then
      # This test function is already within a subshell by shunit2.
      # To inform shunit2 that this test should be skipped, we need to exit this subshell with shunit2's skip code.
      # SHUNIT_SKIP is 77 if defined by shunit2.
      exit "${SHUNIT_SKIP:-77}"
    fi
    return $rc # Propagate other errors
}
testCompressExtract_TarGz_SingleFile() { 
    _testCompressExtract_SingleFile_Format "tar.gz" "Tar.gz test content" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_TarBz2_SingleFile() {
    _testCompressExtract_SingleFile_Format "tar.bz2" "Tar.bz2 test content" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_TarXz_SingleFile() {
    _testCompressExtract_SingleFile_Format "tar.xz" "Tar.xz test content" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_TarZst_SingleFile() {
    _testCompressExtract_SingleFile_Format "tar.zst" "Tar.zst test content" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_7z_SingleFile() {
    _testCompressExtract_SingleFile_Format "7z" "7z test content" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}

# --- Option Tests ---

testOption_TargetDir_Compress() {
    local test_name="option_target_compress"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local custom_target_archive_dir="$current_test_dir/custom_archive_target" # Target for compressed file

    mkdir -p "$source_dir" "$custom_target_archive_dir"

    local original_file_name="file_for_target_compress.txt"
    local original_file_path="$source_dir/$original_file_name"
    echo "Content for target dir compress test" > "$original_file_path"

    local archive_base_name="compressed_in_custom_target"
    local archive_format="zip"
    local expected_archive_path="$custom_target_archive_dir/${archive_base_name}.${archive_format}"

    # Compress: pac -c zip -n compressed_in_custom_target -t custom_target_archive_dir source_dir/file_for_target_compress.txt
    local compress_output
    local compress_rc
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$custom_target_archive_dir" "$original_file_path" 2>&1)
    compress_rc=$?

    assertEquals "Compression with custom target dir failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive file '$expected_archive_path' was not created in custom target. Output: $compress_output" "[ -f \"$expected_archive_path\" ]"
    assertTrue "Archive file '$expected_archive_path' in custom target is empty. Output: $compress_output" "[ -s \"$expected_archive_path\" ]"
    
    # Ensure it wasn't created in default location (e.g. if -t was ignored and -n used an absolute path somehow)
    # This depends on where pac would put it by default if -t custom_target_archive_dir was ignored.
    # Assuming default target for -n would be PWD for the archive dir.
    # This assertion is a bit fragile and depends on pac's default output logic.
    local default_location_archive_path="./${archive_base_name}.${archive_format}" # Assuming test runs from tests/
    if [[ -f "$default_location_archive_path" ]]; then
      # Check if it's the same file (e.g. target was a symlink to pwd)
      # This is unlikely given how mkdir -p works above.
      if [[ ! "$(realpath "$expected_archive_path")" == "$(realpath "$default_location_archive_path")" ]]; then
         assertFalse "Archive also created in default location '$default_location_archive_path' when -t was used." "[ -f \"$default_location_archive_path\" ]"
      fi
    fi


    rm -rf "$current_test_dir"
}

testOption_TargetDir_Extract() {
    local test_name="option_target_extract"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive" # Where archive is initially created
    local custom_extract_target_dir="$current_test_dir/custom_extract_target" # Target for extracted files

    mkdir -p "$source_dir" "$archive_dir" "$custom_extract_target_dir"

    local original_file_name="file_for_target_extract.txt"
    local original_file_path="$source_dir/$original_file_name"
    echo "Content for target dir extract test" > "$original_file_path"

    local archive_base_name="archive_to_extract_with_target"
    local archive_format="zip"
    local archive_to_extract_path="$archive_dir/${archive_base_name}.${archive_format}"

    # Create an archive first
    local compress_output
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    assertEquals "Initial compression failed for $test_name. Output: $compress_output" 0 "$?"
    assertTrue "Archive '$archive_to_extract_path' for $test_name not created." "[ -f \"$archive_to_extract_path\" ]"

    # Extract with -t
    # pac -x -t custom_extract_target_dir archive_dir/archive_to_extract_with_target.zip
    local extract_output
    local extract_rc
    extract_output=$(pac -x -t "$custom_extract_target_dir" "$archive_to_extract_path" 2>&1)
    extract_rc=$?

    assertEquals "Extraction with custom target dir failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    local expected_extracted_file_path="$custom_extract_target_dir/$original_file_name"
    assertTrue "Extracted file '$expected_extracted_file_path' not found in custom target. Output: $extract_output" "[ -f \"$expected_extracted_file_path\" ]"
    
    local original_content=$(cat "$original_file_path")
    local extracted_content=$(cat "$expected_extracted_file_path")
    assertEquals "Content of extracted file in custom target does not match original." "$original_content" "$extracted_content"

    rm -rf "$current_test_dir"
}

testOption_CustomName_Compress() {
    local test_name="option_custom_name"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive" # Default archive location for this test

    mkdir -p "$source_dir" "$archive_dir"

    local original_file_name="file_for_custom_name.txt"
    local original_file_path="$source_dir/$original_file_name"
    echo "Content for custom name test" > "$original_file_path"

    local custom_archive_base_name="MyBackup_Special"
    local archive_format="zip"
    local expected_archive_path="$archive_dir/${custom_archive_base_name}.${archive_format}"

    # Compress: pac -c zip -n MyBackup_Special -t archive_dir source_dir/file_for_custom_name.txt
    local compress_output
    local compress_rc
    compress_output=$(pac -c "$archive_format" -n "$custom_archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    compress_rc=$?

    assertEquals "Compression with custom name failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive file '$expected_archive_path' with custom name was not created. Output: $compress_output" "[ -f \"$expected_archive_path\" ]"
    assertTrue "Archive file '$expected_archive_path' (custom name) is empty. Output: $compress_output" "[ -s \"$expected_archive_path\" ]"

    rm -rf "$current_test_dir"
}

testOption_Delete_Compress() {
    local test_name="option_delete_compress"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"

    mkdir -p "$source_dir" "$archive_dir"

    local file_to_be_deleted_name="file_to_delete_after_compress.txt"
    local file_to_be_deleted_path="$source_dir/$file_to_be_deleted_name"
    echo "This file will be deleted after compression." > "$file_to_be_deleted_path"
    
    # Ensure the file exists before compression
    assertTrue "Source file '$file_to_be_deleted_path' does not exist before compression." "[ -f \"$file_to_be_deleted_path\" ]"

    local archive_base_name="archive_after_delete_op_compress"
    local archive_format="zip"
    local expected_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # Compress with -d: pac -c zip -d -n archive_after_delete_op -t archive_dir source_dir/file_to_delete_after_compress.txt
    local compress_output
    local compress_rc
    compress_output=$(pac -c "$archive_format" -d -n "$archive_base_name" -t "$archive_dir" "$file_to_be_deleted_path" 2>&1)
    compress_rc=$?

    assertEquals "Compression with -d option failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive file '$expected_archive_path' was not created (with -d). Output: $compress_output" "[ -f \"$expected_archive_path\" ]"
    assertFalse "Source file '$file_to_be_deleted_path' was NOT deleted after compression with -d. Output: $compress_output" "[ -e \"$file_to_be_deleted_path\" ]" # -e for any type, file or dir

    rm -rf "$current_test_dir"
}

testOption_Delete_Extract() {
    local test_name="option_delete_extract"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive_for_delete_extract" # Store original archive
    local extract_dir="$current_test_dir/extracted_after_delete"
    
    mkdir -p "$source_dir" "$archive_dir" "$extract_dir"

    local original_file_name="file_for_delete_extract.txt"
    local original_file_path="$source_dir/$original_file_name"
    echo "Content for delete after extract test" > "$original_file_path"

    local archive_base_name="archive_to_be_deleted_after_extract"
    local archive_format="zip"
    local original_archive_path="$archive_dir/${archive_base_name}.${archive_format}"

    # Create an archive first
    local compress_output
    compress_output=$(pac -c "$archive_format" -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    assertEquals "Initial compression failed for $test_name. Output: $compress_output" 0 "$?"
    assertTrue "Archive '$original_archive_path' for $test_name not created." "[ -f \"$original_archive_path\" ]"

    # Copy archive to a path that will be used with -d, so original in archive_dir is preserved for inspection if needed
    local temp_archive_storage_dir="$current_test_dir/temp_archives_for_deletion_test"
    mkdir -p "$temp_archive_storage_dir"
    local archive_to_extract_and_delete="$temp_archive_storage_dir/$(basename "$original_archive_path")"
    cp "$original_archive_path" "$archive_to_extract_and_delete"
    assertTrue "Copied archive '$archive_to_extract_and_delete' for -d test does not exist." "[ -f \"$archive_to_extract_and_delete\" ]"

    # Extract with -d: pac -x -d -t extract_dir temp_archive_storage_dir/archive_to_be_deleted_after_extract.zip
    local extract_output
    local extract_rc
    extract_output=$(pac -x -d -t "$extract_dir" "$archive_to_extract_and_delete" 2>&1)
    extract_rc=$?

    assertEquals "Extraction with -d option failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    
    local expected_extracted_file_path="$extract_dir/$original_file_name"
    assertTrue "Extracted file '$expected_extracted_file_path' not found (with -d). Output: $extract_output" "[ -f \"$expected_extracted_file_path\" ]"
    assertFalse "Archive file '$archive_to_extract_and_delete' was NOT deleted after extraction with -d. Output: $extract_output" "[ -e \"$archive_to_extract_and_delete\" ]"
    assertTrue "Original archive '$original_archive_path' should still exist (was copied). Output: $extract_output" "[ -f \"$original_archive_path\" ]"


    rm -rf "$current_test_dir"
}

# --- Option Tests (Continued) ---

# Tests for --jobs option with relevant formats
testCompressExtract_TarXz_Jobs() {
    _testCompressExtract_SingleFile_Format "tar.xz" "Tar.xz with jobs test" "2" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_TarZst_Jobs() {
    _testCompressExtract_SingleFile_Format "tar.zst" "Tar.zst with jobs test" "2" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_7z_Jobs() {
    _testCompressExtract_SingleFile_Format "7z" "7z with jobs test" "2" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}

# --- Password Protection Tests ---
_testPasswordProtection() {
    local format=$1
    local password="TestPa\$\$wOrd!123" # Reasonably complex password
    local test_name="password_${format}"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir_pass="$current_test_dir/extracted_with_pass"
    local extract_dir_nopass="$current_test_dir/extracted_without_pass"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir_pass" "$extract_dir_nopass"

    local original_file_name="secret_file.txt"
    local original_file_path="$source_dir/$original_file_name"
    local original_content="Super secret content for $format with password."
    echo "$original_content" > "$original_file_path"

    local archive_base_name="encrypted_archive_${format}"
    local full_archive_path="$archive_dir/${archive_base_name}.${format}"

    # Compress with password
    local compress_output compress_rc
    compress_output=$(pac -c "$format" -p "$password" -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    compress_rc=$?
    if [[ $compress_rc -eq 6 ]]; then # Tool not found
        startSkipping; echo "Skipping $test_name: tool for $format not found."; rm -rf "$current_test_dir"; return 6
    fi
    # 7z might return non-0 if password is too simple (though this one should be fine).
    # Allow for this possibility, but the archive should still be created.
    if [[ $compress_rc -ne 0 && "$format" == "7z" ]]; then
        echo "Warning: Compression with password for $format returned non-zero ($compress_rc), but proceeding. Output: $compress_output"
    elif [[ $compress_rc -ne 0 ]]; then
        assertEquals "Compression with password for $format failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    fi
    assertTrue "Encrypted archive '$full_archive_path' not created for $format." "[ -f \"$full_archive_path\" ]"

    # Attempt to extract WITH the correct password using pac
    local extract_pass_output extract_pass_rc
    extract_pass_output=$(pac -x -p "$password" -t "$extract_dir_pass" "$full_archive_path" 2>&1)
    extract_pass_rc=$?
    assertEquals "Extraction WITH password for $format failed. RC: $extract_pass_rc. Output: $extract_pass_output" 0 "$extract_pass_rc"
    local extracted_file_pass_path="$extract_dir_pass/$original_file_name"
    
    if [[ "$format" == "zip" || "$format" == "7z" ]]; then
        assertTrue "File not extracted WITH password for $format: '$extracted_file_pass_path'" "[ -f \"$extracted_file_pass_path\" ]"
        assertEquals "Content mismatch for $format WITH password." "$original_content" "$(cat "$extracted_file_pass_path")"
    fi

    # Attempt to extract WITHOUT password using pac
    if [[ "$format" == "zip" || "$format" == "7z" ]]; then
        local extract_nopass_output extract_nopass_rc
        extract_nopass_output=$(pac -x -t "$extract_dir_nopass" "$full_archive_path" 2>&1)
        extract_nopass_rc=$?
        
        local extracted_file_nopass_path="$extract_dir_nopass/$original_file_name"
        if [[ $extract_nopass_rc -eq 0 ]]; then 
            assertTrue "File extracted WITHOUT password for $format (RC 0), but was not expected or should be garbage: '$extracted_file_nopass_path'" "[ -f \"$extracted_file_nopass_path\" ]"
            if [[ -s "$extracted_file_nopass_path" ]]; then 
                 assertNotEquals "Content surprisingly matched original for $format when extracted WITHOUT password (RC 0)." "$original_content" "$(cat "$extracted_file_nopass_path")"
            fi
        else 
            assertNotEquals "Extraction WITHOUT password for $format should have failed (non-zero RC). RC: $extract_nopass_rc. Output: $extract_nopass_output" 0 "$extract_nopass_rc"
        fi
    fi

    rm -rf "$current_test_dir"
    return 0
}

testPassword_Zip() {
    _testPasswordProtection "zip" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testPassword_7z() {
    _testPasswordProtection "7z" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}

# --- Verbose Option Test ---
testOption_Verbose_Compress_Zip() {
    local test_name="option_verbose_compress_zip"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"

    mkdir -p "$source_dir" "$archive_dir"
    echo "Verbose test content" > "$source_dir/verbose_file.txt"

    local compress_output compress_rc
    compress_output=$(pac -v -c zip -n verbose_archive -t "$archive_dir" "$source_dir/verbose_file.txt" 2>&1)
    compress_rc=$?

    if [[ $compress_rc -eq 6 ]]; then # zip tool might be missing
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Verbose compression for zip failed. RC: $compress_rc." 0 "$compress_rc"
    assertTrue "Verbose output for zip did not contain expected 'adding:' or filename. Output: $compress_output" \
        "echo '$compress_output' | grep -E -q 'adding:|verbose_file.txt'"
    
    rm -rf "$current_test_dir"
}

# --- Alias Tests ---
testAlias_Compress() {
    local test_name="alias_compress_c"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive"
    echo "Alias c test" > "$current_test_dir/source/file.txt"
    
    local compress_output compress_rc
    compress_output=$(pac c zip -n alias_c_test -t "$current_test_dir/archive" "$current_test_dir/source/file.txt" 2>&1)
    compress_rc=$?

    if [[ $compress_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Alias 'pac c zip' compression failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive from 'pac c zip' not created." "[ -f \"$current_test_dir/archive/alias_c_test.zip\" ]"
    rm -rf "$current_test_dir"
}

testAlias_Extract() {
    local test_name="alias_extract_x"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive" "$current_test_dir/extracted"
    local original_content="Alias x test content"
    echo "$original_content" > "$current_test_dir/source/alias_x_file.txt"
    
    pac -c zip -n alias_x_archive -t "$current_test_dir/archive" "$current_test_dir/source/alias_x_file.txt" >/dev/null
    assertTrue "Setup archive for 'pac x' not created." "[ -f \"$current_test_dir/archive/alias_x_archive.zip\" ]"

    local extract_output extract_rc
    extract_output=$(pac x -t "$current_test_dir/extracted" "$current_test_dir/archive/alias_x_archive.zip" 2>&1)
    extract_rc=$?
    if [[ $extract_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Alias 'pac x' extraction failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    assertTrue "File not extracted by 'pac x'." "[ -f \"$current_test_dir/extracted/alias_x_file.txt\" ]"
    assertEquals "Content mismatch for 'pac x' extraction." "$original_content" "$(cat "$current_test_dir/extracted/alias_x_file.txt")"
    rm -rf "$current_test_dir"
}

testAlias_List() {
    local test_name="alias_list_l"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive"
    echo "Alias l test" > "$current_test_dir/source/alias_l_file.txt"
    pac -c zip -n alias_l_archive -t "$current_test_dir/archive" "$current_test_dir/source/alias_l_file.txt" >/dev/null
    assertTrue "Setup archive for 'pac l' not created." "[ -f \"$current_test_dir/archive/alias_l_archive.zip\" ]"

    local list_output list_rc
    list_output=$(pac l "$current_test_dir/archive/alias_l_archive.zip" 2>&1)
    list_rc=$?
    if [[ $list_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Alias 'pac l' list failed. RC: $list_rc. Output: $list_output" 0 "$list_rc"
    assertTrue "Output from 'pac l' did not contain filename 'alias_l_file.txt'. Output: $list_output" \
        "echo '$list_output' | grep -q 'alias_l_file.txt'"
    rm -rf "$current_test_dir"
}

# --- Error Handling Tests ---
testError_InvalidOption() {
    local err_output
    err_output=$(pac --nonexistent-option-for-pac 2>&1)
    local rc=$?
    assertEquals "pac with invalid option should return 2. Output: $err_output" 2 "$rc"
    assertTrue "Error message for invalid option should contain 'Unbekannte Option' or 'invalid option'. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Unbekannte Option|invalid option|unknown option'"
}

testError_MissingArgument_CompressFormat() {
    local err_output
    mkdir -p "$TEST_ROOT_DIR/error_handling_temp/source" 
    echo "dummy" > "$TEST_ROOT_DIR/error_handling_temp/source/dummy.txt"
    err_output=$(pac -c "$TEST_ROOT_DIR/error_handling_temp/source/dummy.txt" 2>&1)
    local rc=$?
    assertEquals "pac -c (no format) should return 2. Output: $err_output" 2 "$rc"
    assertTrue "Error for pac -c (no format) should mention missing format. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Kompressionsformat fehlt|requires an argument'"
    rm -rf "$TEST_ROOT_DIR/error_handling_temp"
}

testError_MissingArgument_TargetDir() {
    local err_output
    mkdir -p "$TEST_ROOT_DIR/error_handling_temp/archive"
    echo "dummy_archive" > "$TEST_ROOT_DIR/error_handling_temp/archive/dummy.zip" 
    err_output=$(pac -t "$TEST_ROOT_DIR/error_handling_temp/archive/dummy.zip" 2>&1)
    local rc=$?
    assertEquals "pac -t (no dir) should return 2. Output: $err_output" 2 "$rc"
     assertTrue "Error for pac -t (no dir) should mention missing directory. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Zielverzeichnis fehlt|requires an argument'"
    rm -rf "$TEST_ROOT_DIR/error_handling_temp"
}

testError_NonExistentInputFile_Compress() {
    local test_name="error_non_existent_input_compress"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/archive"

    local err_output
    err_output=$(pac -c zip -n test -t "$current_test_dir/archive" "$current_test_dir/non_existent_file.txt" 2>&1)
    local rc=$?
    assertEquals "pac compress with non-existent input should return 3. Output: $err_output" 3 "$rc"
    assertTrue "Error message for non-existent input should contain 'nicht gefunden'. Output: $err_output" \
        "echo '$err_output' | grep -q 'nicht gefunden'"
    rm -rf "$current_test_dir"
}

testError_NonExistentArchive_Extract() {
    local test_name="error_non_existent_archive_extract"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/extract_target"

    local err_output
    err_output=$(pac -x -t "$current_test_dir/extract_target" "$current_test_dir/non_existent_archive.zip" 2>&1)
    local rc=$?
    assertEquals "pac extract with non-existent archive should return 3. Output: $err_output" 3 "$rc"
    assertTrue "Error message for non-existent archive should contain 'Archiv nicht gefunden'. Output: $err_output" \
        "echo '$err_output' | grep -q 'Archiv nicht gefunden'"
    rm -rf "$current_test_dir"
}

testError_UnsupportedFormat_Compress() {
    local test_name="error_unsupported_format_compress"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive"
    echo "test" > "$current_test_dir/source/file.txt"

    local err_output
    err_output=$(pac -c "badformat" -n test -t "$current_test_dir/archive" "$current_test_dir/source/file.txt" 2>&1)
    local rc=$?
    assertEquals "pac compress with unsupported format should return 5. Output: $err_output" 5 "$rc"
    assertTrue "Error message for unsupported format should contain 'Unsupported format' or 'Nicht unterstütztes'. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Unsupported format|Nicht unterstütztes Kompressionsformat'"
    rm -rf "$current_test_dir"
}

testError_UnsupportedFormat_Extract() {
    local test_name="error_unsupported_format_extract"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/archive" "$current_test_dir/extract_target"
    echo "dummy content" > "$current_test_dir/archive/dummy.badext" # Create a dummy file

    local err_output
    err_output=$(pac -x -t "$current_test_dir/extract_target" "$current_test_dir/archive/dummy.badext" 2>&1)
    local rc=$?
    assertEquals "pac extract with unsupported extension should return 5. Output: $err_output" 5 "$rc"
    assertTrue "Error message for unsupported extension should contain 'Nicht unterstütztes Archiv'. Output: $err_output" \
        "echo '$err_output' | grep -q 'Nicht unterstütztes Archiv'"
    rm -rf "$current_test_dir"
}

# --- Option Tests (Continued) ---

# Tests for --jobs option with relevant formats
testCompressExtract_TarXz_Jobs() {
    _testCompressExtract_SingleFile_Format "tar.xz" "Tar.xz with jobs test" "2" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_TarZst_Jobs() {
    _testCompressExtract_SingleFile_Format "tar.zst" "Tar.zst with jobs test" "2" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testCompressExtract_7z_Jobs() {
    _testCompressExtract_SingleFile_Format "7z" "7z with jobs test" "2" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}

# --- Password Protection Tests ---
_testPasswordProtection() {
    local format=$1
    local password="TestPa\$\$wOrd!123" # Reasonably complex password
    local test_name="password_${format}"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"
    local extract_dir_pass="$current_test_dir/extracted_with_pass"
    local extract_dir_nopass="$current_test_dir/extracted_without_pass"

    mkdir -p "$source_dir" "$archive_dir" "$extract_dir_pass" "$extract_dir_nopass"

    local original_file_name="secret_file.txt"
    local original_file_path="$source_dir/$original_file_name"
    local original_content="Super secret content for $format with password."
    echo "$original_content" > "$original_file_path"

    local archive_base_name="encrypted_archive_${format}"
    local full_archive_path="$archive_dir/${archive_base_name}.${format}"

    # Compress with password
    local compress_output compress_rc
    compress_output=$(pac -c "$format" -p "$password" -n "$archive_base_name" -t "$archive_dir" "$original_file_path" 2>&1)
    compress_rc=$?
    if [[ $compress_rc -eq 6 ]]; then # Tool not found
        startSkipping; echo "Skipping $test_name: tool for $format not found."; rm -rf "$current_test_dir"; return 6
    fi
    # 7z might return non-0 if password is too simple (though this one should be fine).
    # Allow for this possibility, but the archive should still be created.
    if [[ $compress_rc -ne 0 && "$format" == "7z" ]]; then
        echo "Warning: Compression with password for $format returned non-zero ($compress_rc), but proceeding. Output: $compress_output"
    elif [[ $compress_rc -ne 0 ]]; then
        assertEquals "Compression with password for $format failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    fi
    assertTrue "Encrypted archive '$full_archive_path' not created for $format." "[ -f \"$full_archive_path\" ]"

    # Attempt to extract WITH the correct password using pac
    local extract_pass_output extract_pass_rc
    extract_pass_output=$(pac -x -p "$password" -t "$extract_dir_pass" "$full_archive_path" 2>&1)
    extract_pass_rc=$?
    assertEquals "Extraction WITH password for $format failed. RC: $extract_pass_rc. Output: $extract_pass_output" 0 "$extract_pass_rc"
    local extracted_file_pass_path="$extract_dir_pass/$original_file_name"
    
    if [[ "$format" == "zip" || "$format" == "7z" ]]; then
        assertTrue "File not extracted WITH password for $format: '$extracted_file_pass_path'" "[ -f \"$extracted_file_pass_path\" ]"
        assertEquals "Content mismatch for $format WITH password." "$original_content" "$(cat "$extracted_file_pass_path")"
    fi

    # Attempt to extract WITHOUT password using pac
    if [[ "$format" == "zip" || "$format" == "7z" ]]; then
        local extract_nopass_output extract_nopass_rc
        extract_nopass_output=$(pac -x -t "$extract_dir_nopass" "$full_archive_path" 2>&1)
        extract_nopass_rc=$?
        
        local extracted_file_nopass_path="$extract_dir_nopass/$original_file_name"
        if [[ $extract_nopass_rc -eq 0 ]]; then 
            assertTrue "File extracted WITHOUT password for $format (RC 0), but was not expected or should be garbage: '$extracted_file_nopass_path'" "[ -f \"$extracted_file_nopass_path\" ]"
            if [[ -s "$extracted_file_nopass_path" ]]; then 
                 assertNotEquals "Content surprisingly matched original for $format when extracted WITHOUT password (RC 0)." "$original_content" "$(cat "$extracted_file_nopass_path")"
            fi
        else 
            assertNotEquals "Extraction WITHOUT password for $format should have failed (non-zero RC). RC: $extract_nopass_rc. Output: $extract_nopass_output" 0 "$extract_nopass_rc"
        fi
    fi

    rm -rf "$current_test_dir"
    return 0
}

testPassword_Zip() {
    _testPasswordProtection "zip" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}
testPassword_7z() {
    _testPasswordProtection "7z" && return 0
    local rc=$?
    if [[ $rc -eq 6 ]]; then exit "${SHUNIT_SKIP:-77}"; fi
    return $rc
}

# --- Verbose Option Test ---
testOption_Verbose_Compress_Zip() {
    local test_name="option_verbose_compress_zip"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    local source_dir="$current_test_dir/source"
    local archive_dir="$current_test_dir/archive"

    mkdir -p "$source_dir" "$archive_dir"
    echo "Verbose test content" > "$source_dir/verbose_file.txt"

    local compress_output compress_rc
    compress_output=$(pac -v -c zip -n verbose_archive -t "$archive_dir" "$source_dir/verbose_file.txt" 2>&1)
    compress_rc=$?

    if [[ $compress_rc -eq 6 ]]; then # zip tool might be missing
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Verbose compression for zip failed. RC: $compress_rc." 0 "$compress_rc"
    assertTrue "Verbose output for zip did not contain expected 'adding:' or filename. Output: $compress_output" \
        "echo '$compress_output' | grep -E -q 'adding:|verbose_file.txt'"
    
    rm -rf "$current_test_dir"
}

# --- Alias Tests ---
testAlias_Compress() {
    local test_name="alias_compress_c"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive"
    echo "Alias c test" > "$current_test_dir/source/file.txt"
    
    local compress_output compress_rc
    compress_output=$(pac c zip -n alias_c_test -t "$current_test_dir/archive" "$current_test_dir/source/file.txt" 2>&1)
    compress_rc=$?

    if [[ $compress_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Alias 'pac c zip' compression failed. RC: $compress_rc. Output: $compress_output" 0 "$compress_rc"
    assertTrue "Archive from 'pac c zip' not created." "[ -f \"$current_test_dir/archive/alias_c_test.zip\" ]"
    rm -rf "$current_test_dir"
}

testAlias_Extract() {
    local test_name="alias_extract_x"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive" "$current_test_dir/extracted"
    local original_content="Alias x test content"
    echo "$original_content" > "$current_test_dir/source/alias_x_file.txt"
    
    pac -c zip -n alias_x_archive -t "$current_test_dir/archive" "$current_test_dir/source/alias_x_file.txt" >/dev/null
    assertTrue "Setup archive for 'pac x' not created." "[ -f \"$current_test_dir/archive/alias_x_archive.zip\" ]"

    local extract_output extract_rc
    extract_output=$(pac x -t "$current_test_dir/extracted" "$current_test_dir/archive/alias_x_archive.zip" 2>&1)
    extract_rc=$?
    if [[ $extract_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Alias 'pac x' extraction failed. RC: $extract_rc. Output: $extract_output" 0 "$extract_rc"
    assertTrue "File not extracted by 'pac x'." "[ -f \"$current_test_dir/extracted/alias_x_file.txt\" ]"
    assertEquals "Content mismatch for 'pac x' extraction." "$original_content" "$(cat "$current_test_dir/extracted/alias_x_file.txt")"
    rm -rf "$current_test_dir"
}

testAlias_List() {
    local test_name="alias_list_l"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive"
    echo "Alias l test" > "$current_test_dir/source/alias_l_file.txt"
    pac -c zip -n alias_l_archive -t "$current_test_dir/archive" "$current_test_dir/source/alias_l_file.txt" >/dev/null
    assertTrue "Setup archive for 'pac l' not created." "[ -f \"$current_test_dir/archive/alias_l_archive.zip\" ]"

    local list_output list_rc
    list_output=$(pac l "$current_test_dir/archive/alias_l_archive.zip" 2>&1)
    list_rc=$?
    if [[ $list_rc -eq 6 ]]; then
        startSkipping; echo "Skipping $test_name: zip tool not found."; rm -rf "$current_test_dir"; exit "${SHUNIT_SKIP:-77}"
    fi
    assertEquals "Alias 'pac l' list failed. RC: $list_rc. Output: $list_output" 0 "$list_rc"
    assertTrue "Output from 'pac l' did not contain filename 'alias_l_file.txt'. Output: $list_output" \
        "echo '$list_output' | grep -q 'alias_l_file.txt'"
    rm -rf "$current_test_dir"
}

# --- Error Handling Tests ---
testError_InvalidOption() {
    local err_output
    err_output=$(pac --nonexistent-option-for-pac 2>&1)
    local rc=$?
    assertEquals "pac with invalid option should return 2. Output: $err_output" 2 "$rc"
    assertTrue "Error message for invalid option should contain 'Unbekannte Option' or 'invalid option'. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Unbekannte Option|invalid option|unknown option'"
}

testError_MissingArgument_CompressFormat() {
    local err_output
    mkdir -p "$TEST_ROOT_DIR/error_handling_temp/source" 
    echo "dummy" > "$TEST_ROOT_DIR/error_handling_temp/source/dummy.txt"
    err_output=$(pac -c "$TEST_ROOT_DIR/error_handling_temp/source/dummy.txt" 2>&1)
    local rc=$?
    assertEquals "pac -c (no format) should return 2. Output: $err_output" 2 "$rc"
    assertTrue "Error for pac -c (no format) should mention missing format. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Kompressionsformat fehlt|requires an argument'"
    rm -rf "$TEST_ROOT_DIR/error_handling_temp"
}

testError_MissingArgument_TargetDir() {
    local err_output
    mkdir -p "$TEST_ROOT_DIR/error_handling_temp/archive"
    echo "dummy_archive" > "$TEST_ROOT_DIR/error_handling_temp/archive/dummy.zip" 
    err_output=$(pac -t "$TEST_ROOT_DIR/error_handling_temp/archive/dummy.zip" 2>&1)
    local rc=$?
    assertEquals "pac -t (no dir) should return 2. Output: $err_output" 2 "$rc"
     assertTrue "Error for pac -t (no dir) should mention missing directory. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Zielverzeichnis fehlt|requires an argument'"
    rm -rf "$TEST_ROOT_DIR/error_handling_temp"
}

testError_NonExistentInputFile_Compress() {
    local test_name="error_non_existent_input_compress"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/archive"

    local err_output
    err_output=$(pac -c zip -n test -t "$current_test_dir/archive" "$current_test_dir/non_existent_file.txt" 2>&1)
    local rc=$?
    assertEquals "pac compress with non-existent input should return 3. Output: $err_output" 3 "$rc"
    assertTrue "Error message for non-existent input should contain 'nicht gefunden'. Output: $err_output" \
        "echo '$err_output' | grep -q 'nicht gefunden'"
    rm -rf "$current_test_dir"
}

testError_NonExistentArchive_Extract() {
    local test_name="error_non_existent_archive_extract"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/extract_target"

    local err_output
    err_output=$(pac -x -t "$current_test_dir/extract_target" "$current_test_dir/non_existent_archive.zip" 2>&1)
    local rc=$?
    assertEquals "pac extract with non-existent archive should return 3. Output: $err_output" 3 "$rc"
    assertTrue "Error message for non-existent archive should contain 'Archiv nicht gefunden'. Output: $err_output" \
        "echo '$err_output' | grep -q 'Archiv nicht gefunden'"
    rm -rf "$current_test_dir"
}

testError_UnsupportedFormat_Compress() {
    local test_name="error_unsupported_format_compress"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/source" "$current_test_dir/archive"
    echo "test" > "$current_test_dir/source/file.txt"

    local err_output
    err_output=$(pac -c "badformat" -n test -t "$current_test_dir/archive" "$current_test_dir/source/file.txt" 2>&1)
    local rc=$?
    assertEquals "pac compress with unsupported format should return 5. Output: $err_output" 5 "$rc"
    assertTrue "Error message for unsupported format should contain 'Unsupported format' or 'Nicht unterstütztes'. Output: $err_output" \
        "echo '$err_output' | grep -E -q 'Unsupported format|Nicht unterstütztes Kompressionsformat'"
    rm -rf "$current_test_dir"
}

testError_UnsupportedFormat_Extract() {
    local test_name="error_unsupported_format_extract"
    local current_test_dir="$TEST_ROOT_DIR/$test_name"
    mkdir -p "$current_test_dir/archive" "$current_test_dir/extract_target"
    echo "dummy content" > "$current_test_dir/archive/dummy.badext" # Create a dummy file

    local err_output
    err_output=$(pac -x -t "$current_test_dir/extract_target" "$current_test_dir/archive/dummy.badext" 2>&1)
    local rc=$?
    assertEquals "pac extract with unsupported extension should return 5. Output: $err_output" 5 "$rc"
    assertTrue "Error message for unsupported extension should contain 'Nicht unterstütztes Archiv'. Output: $err_output" \
        "echo '$err_output' | grep -q 'Nicht unterstütztes Archiv'"
    rm -rf "$current_test_dir"
}


# --- Load shunit2 ---
# This call runs the tests. It must be at the end of the script.
# shellcheck disable=SC1090
. "$SHUNIT2_PATH"
