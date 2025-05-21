#!/usr/bin/env bash

pac() {
    # Farbdefinitionen
    # Color definitions for user messages
    local use_color               # Flag to indicate if colors should be used
    local RED GREEN YELLOW BLUE NC # ANSI escape codes for colors (No Color)
    local tput_colors_val         # Temporary variable for tput output

    # Determine if colors should be used
    # Colors are enabled if stdout is a TTY and tput reports at least 8 colors.
    tput_colors_val=$(tput colors 2>/dev/null || echo 0) # Get number of colors or 0 on error
    if [[ -t 1 && "$tput_colors_val" -ge 8 ]]; then
        use_color=1
    else
        use_color=0
    fi

    # Assign color codes if use_color is enabled
    if [[ "$use_color" -eq 1 ]]; then
        RED=$(printf '\033[0;31m')     # Red
        GREEN=$(printf '\033[0;32m')   # Green
        YELLOW=$(printf '\033[0;33m')  # Yellow
        BLUE=$(printf '\033[0;34m')    # Blue
        NC=$(printf '\033[0m')        # No Color (reset)
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        NC=""
    fi

    local usage
    read -r -d '' usage <<'HELPTEXT'
PAC - Pack And Compress
Version: 1.1.0 (Enhanced Help)
A versatile command-line tool for easy archive compression and extraction.

SYNTAX
    pac [MODE] [OPTIONS] file1 [file2 ...]
    pac [ALIAS] [format] file1 [file2 ...]

MODES & MAIN OPTIONS
    -c, --compress FORMAT   Compress mode. Requires a FORMAT.
                            Supported formats: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z.
    -x, --extract           Extract mode. This is the default mode if no other mode is specified.
                            Automatically determines format from file extension.
    -l, --list              List mode. Shows the contents of the specified archive(s).

GENERAL OPTIONS
    -t, --target DIRECTORY  Specify target directory for compressed archives or extracted files.
                            Default: Current directory (".").
    -n, --name FILENAME     Custom archive name (without extension).
                            Default: Based on input file/directory name(s). If multiple inputs
                            are provided without -n, "archive_YYYYMMDD_HHMMSS" is used.
    -d, --delete            Delete original file(s) or archive(s) after successful operation.
                            Use with caution.
    -v, --verbose           Enable verbose output to show detailed progress.
    -h, --help              Show this comprehensive help message and exit.
    --debug                 Enable debug output for troubleshooting.

FILTERING OPTIONS (primarily for compression)
    -e, --exclude PATTERN   Exclude files/directories matching PATTERN. Can be used multiple times.
                            Example: -e "*.log" -e "tmp/"
    -i, --include PATTERN   Include only files/directories matching PATTERN. Can be used multiple times.
                            Note: Include patterns are applied before exclude patterns. (Currently, this
                            option is parsed but not directly used by zip/tar compression commands within pac.sh.
                            Exclude patterns (-e or from filter file) are used by zip.)
                            Example: -i "*.txt" -i "*.md"
    # -f, --filter FILE     (This option has been removed as the 'filter_file' variable was unused.)
    #                         Read include (+) and exclude (-) patterns from a specified FILE.
    #                         See PATTERN FILE FORMAT section for details.

PERFORMANCE & SECURITY (compression)
    -j, --jobs NUM          Set the number of processor cores for parallel compression (for .tar.xz, .tar.zst).
                            Default: Number of available cores, or 2 if detection fails.
    -p, --password PASS     Set a password for encryption. Only supported for zip and 7z formats.
                            Warning: Using passwords on the command line can be insecure.

SUPPORTED FORMATS
    Compression:  tar, tar.gz (tgz), tar.bz2 (tbz2), tar.xz (txz), tar.zst, zip, 7z
    Extraction:   tar, tar.gz (tgz), tar.bz2 (tbz2), tar.xz (txz), tar.zst, zip, 7z
                  (Format for extraction is auto-detected from the file extension)
    Listing:      tar, tar.gz (tgz), tar.bz2 (tbz2), tar.xz (txz), tar.zst, zip, 7z

ALIASES (Shortcuts for common operations)
    pac c FORMAT file(s)    Compress: pac c zip myfiles.txt (equivalent to: pac -c zip myfiles.txt)
    pac x archive(s)        Extract:  pac x myarchive.zip (equivalent to: pac -x myarchive.zip)
    pac l archive(s)        List:     pac l myarchive.tar.gz (equivalent to: pac -l myarchive.tar.gz)

EXAMPLES

  Basic Compression:
    # Compress a single file to file.zip
    pac -c zip file.txt
    # Compress a directory to directory.tar.gz (common for Linux/macOS)
    pac -c tar.gz my_directory/
    # Compress multiple files into data.tar.bz2
    pac -c tar.bz2 file1.doc data.xls image.jpg
    # Use alias for compression
    pac c 7z important_files/

  Basic Extraction:
    # Extract archive.zip to the current directory
    pac archive.zip
    # Extract backup.tar.gz (default mode is -x)
    pac backup.tar.gz
    # Extract multiple archives
    pac photos.zip documents.tar.xz
    # Use alias for extraction
    pac x old_backup.7z

  Listing Archive Contents:
    # List contents of an archive
    pac -l my_data.tar.zst
    # Use alias for listing
    pac l project_files.zip

  Custom Naming and Targeting:
    # Compress file.txt to backup_manual.zip in 'archives' directory
    pac -c zip -n backup_manual -t archives/ file.txt
    # Extract my_archive.tar to 'extracted_files' directory
    pac -t extracted_files/ my_archive.tar
    # Compress 'src' dir to 'releases/project-v1.0.tar.gz'
    pac -n project-v1.0 -c tar.gz -t releases/ src/

  Deleting Originals:
    # Compress 'logs' directory and delete it afterwards
    pac -c tar.gz -d logs/
    # Extract 'data.zip' and delete the archive afterwards
    pac -d data.zip

  Filtering during Compression:
    # Compress 'project/' excluding all '.tmp' files and 'build/' directory
    pac -c zip -e "*.tmp" -e "build/" project/
    # Compress 'documents/' including only '.pdf' and '.docx' files
    pac -c tar.gz -i "*.pdf" -i "*.docx" documents/
    # Compress 'src/' using a filter file named 'my_patterns.txt'
    pac -c zip -f my_patterns.txt src/

  Advanced Compression:
    # Compress 'large_data/' to 'backup.tar.xz' using 4 parallel jobs
    pac -c tar.xz -j 4 -n backup large_data/
    # Create a password-protected zip file (interactive password prompt if PASS is empty)
    pac -c zip -p "mySecret" sensitive_docs/
    # For 7z with password:
    pac -c 7z -p "anotherSecret" private_collection/

# PATTERN FILE FORMAT (Note: -f/--filter option has been removed.)
#  Previously, this section described the format for a filter file.
#  If this functionality is re-added, this section should be updated.

EXIT CODES
    0   Success
    1   General error (e.g., tool failure during compress/extract)
    2   Usage error (e.g., invalid option, missing argument)
    3   Input file / archive not found
    4   Permission error (e.g., cannot create/write to target directory)
    5   Invalid or unsupported archive format for the operation
    6   Required dependency (tool like tar, gzip) not found

TIPS
    • If no mode (-c, -x, -l) is given, 'pac' defaults to extraction (-x).
    • For compression, if -n is not used, archive names are based on input names.
      If multiple inputs are given without -n, a name like 'archive_YYYYMMDD_HHMMSS.format' is generated.
    • Patterns for -e and -i should be quoted to prevent shell expansion.
    • Use --debug for troubleshooting to see detailed command execution.
    • Ensure you have the necessary tools (tar, gzip, zip, etc.) installed for the formats you use.
HELPTEXT

    # Logging-Funktionen
    # Logging functions using printf for better portability and color handling.
    # Colors are used only if use_color is 1.
    # Logging functions using printf for better portability and color handling.
    # Uses :- default shell parameter expansion for color variables to prevent errors if they are unset.
    log_info() { local message="$*"; printf "%bINFO:%b %s\n" "${BLUE:-}" "${NC:-}" "$message"; }
    log_success() { local message="$*"; printf "%bSUCCESS:%b %s\n" "${GREEN:-}" "${NC:-}" "$message"; }
    log_warning() { local message="$*"; printf "%bWARNING:%b %s\n" "${YELLOW:-}" "${NC:-}" "$message" >&2; }
    log_error() { local message="$*"; printf "%bERROR:%b %s\n" "${RED:-}" "${NC:-}" "$message" >&2; }

    # Function to check for presence of essential command-line tools.
    # This function only warns if a tool is missing. Specific operations will fail
    # with exit code 6 if their required tool is critically missing.
    check_dependencies() {
        local tool                # Loop variable for tools
        local -a tools_to_check   # Array of tools to check
        tools_to_check=("tar" "gzip" "bzip2" "xz" "zstd" "zip" "7z" "pv") # 'pv' is optional, not critical

        log_info "Checking for necessary tools..."
        for tool in "${tools_to_check[@]}"; do
            if ! command -v "$tool" &>/dev/null; then
                log_warning "$tool is not installed. Some formats or features may not work."
            fi
        done
    }
	
    # --- Initialize script variables and default values ---
    local debug_mode=false                # Debug mode: off by default
    local operation_mode="extract"        # Default operation mode: extract
    local verbose_output=false            # Verbose output: off by default
    local delete_after_operation=false    # Delete original files after operation: off by default
    local target_directory="."            # Default target directory for output: current directory
    local custom_archive_name=""          # Custom archive name: empty by default
    local compression_format=""           # Compression format: empty by default
    local -a exclude_patterns=()          # Array for exclude patterns
    local -a include_patterns=()          # Array for include patterns (Note: current zip/tar usage in pac.sh might not fully support this)
    local -a input_files=()               # Array for input files/directories
    local user_jobs_specification=""      # Stores user's input for -j option (empty if not specified)
    local num_jobs                        # Number of jobs for parallel operations (e.g., for xz, zstd)
    local output_archive_path             # Full path for the output archive (primarily used in compress mode)
    local archive_password=""             # Password for encryption: empty by default

    # Set default number of jobs based on available processors, fallback to 2.
    # This value is used if the user does not specify with -j.
    if ! num_jobs=$(nproc 2>/dev/null); then
        num_jobs=2 # Fallback if nproc command fails or is not available
    elif [[ -z "$num_jobs" || "$num_jobs" -lt 1 ]]; then # Handles cases where nproc might return empty or 0
        num_jobs=2
    fi
    
    # Diagnostic function for debug mode. Prints messages only if debug_mode is true.
    debug_info() {
        if [[ "$debug_mode" == "true" ]]; then
            # Using printf for consistency, though echo is fine here.
            printf "DEBUG: %s\n" "$*"
        fi
    }

    # Bessere Argument-Parsing-Funktion
    # Function to parse command-line arguments.
    # Uses getopt for robust option parsing and handles simple aliases (c, x, l) beforehand.
    # Populates script-level variables (e.g., operation_mode, compression_format, input_files) based on parsed options.
    parse_args() {
        # This function parses command-line arguments using getopt.
        # It handles standard options and also preprocesses simple aliases (c, x, l)
        # to convert them into their getopt-compatible option forms (e.g., 'c' becomes '-c').
        
        local -a args_to_parse=() # Array to hold arguments after potential alias preprocessing.
        
        # Pre-processing for simple aliases (e.g., 'pac c zip file.txt' instead of 'pac -c zip file.txt').
        # This block checks if the first argument is one of the known aliases ('c', 'x', 'l').
        # If so, it reconstructs `args_to_parse` to include the corresponding option (e.g., '-c')
        # and any associated arguments (like format for 'c'), followed by the remaining input files.
        if [[ $# -gt 0 ]]; then # Check if any arguments are provided to 'pac'.
            case "$1" in
                c) # Compress alias: 'pac c format file1 ...'
                    args_to_parse+=("-c") # Replace 'c' with '-c'.
                    shift # Consume the 'c' alias.
                    if [[ $# -gt 0 ]]; then # Next argument is expected to be the compression format.
                        args_to_parse+=("$1") # Add format to arguments for getopt.
                        shift # Consume format.
                    else
                        # Error if format is missing after 'c' alias.
                        log_error "Kompressionsformat fehlt für Alias 'c'."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    # All further arguments are considered input files/directories.
                    # Quote "$@" to handle filenames with spaces correctly if they are ever not consumed by `shift` earlier.
                    while [[ $# -gt 0 ]]; do
                        args_to_parse+=("$1")
                        shift
                    done
                    ;;
                x) # Extract alias: 'pac x file1 ...'
                    args_to_parse+=("-x") # Replace 'x' with '-x'.
                    shift # Consume 'x'.
                    args_to_parse+=("$@") # Add all remaining arguments as input files. Quoted.
                    set -- # Clear original positional parameters as they've been fully processed.
                    ;;
                l) # List alias: 'pac l file1 ...'
                    args_to_parse+=("-l") # Replace 'l' with '-l'.
                    shift # Consume 'l'.
                    args_to_parse+=("$@") # Add all remaining arguments as input files. Quoted.
                    set -- 
                    ;;
                *) # Not an alias, or an option already starting with '-' (e.g., -c, --compress).
                    args_to_parse=("$@") # Use original arguments directly for getopt. Quoted.
                    ;;
            esac
        else
             # No arguments provided to the 'pac' script.
             args_to_parse=("$@") # Pass empty array to getopt. Quoted.
        fi

        local parsed_options_str # Variable to store the normalized options string from getopt. Renamed from 'options'.
        
        # Use getopt to parse the (potentially pre-processed) arguments.
        # -o: Defines short options. A colon (:) after an option indicates it requires an argument.
        # --long: Defines long options. Similar use of colon for arguments.
        # -n 'pac': Sets the program name for error messages generated by getopt.
        # -- "${args_to_parse[@]}": The arguments to be parsed. The '--' signifies the end of options processing by getopt.
        # Quoted array expansion.
        if ! parsed_options_str="$(getopt -o c:xlt:vdn:e:i:j:p:h --long compress:,extract,list,target:,verbose,delete,name:,exclude:,include:,jobs:,password:,help,debug -n 'pac' -- "${args_to_parse[@]}")"; then
            # getopt detected an error (e.g., invalid option, missing argument for an option that requires one).
            # getopt itself typically prints an error message to stderr.
            echo "$usage" >&2 # Display full usage information to the user.
            return 2 # Return code 2 for usage errors.
        fi

        # Replace the script's positional parameters ($1, $2, etc.) with the normalized options string from getopt.
        # This makes iterating through options and their arguments in a structured way easier.
        # Quoted "$parsed_options_str".
        eval set -- "$parsed_options_str"

        # Loop through the getopt-processed options and arguments.
        # After `eval set -- "$parsed_options_str"`, $1, $2, etc., are set according to getopt's output.
        # Options are expanded (e.g., -cf becomes -c -f), and arguments are placed after their respective options.
        while true; do
            # "$1" is quoted in the case statement.
            case "$1" in
                -c|--compress) # Compress mode option.
                    operation_mode="compress" # Set main operation mode.
                    # Check if the required argument (format) for -c/--compress is present.
                    # getopt places the argument in $2. If $2 is empty or starts with '--'
                    # (signifying another long option), it means the argument was missing.
                    if [[ -z "$2" || "$2" == --* ]]; then 
                        log_error "Kompressionsformat fehlt für Option \"-c/--compress\"."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    compression_format="$2" # Assign the compression format.
                    shift 2 # Consume the option ('-c') and its argument (format).
                    ;;
                -x|--extract) # Extract mode option.
                    operation_mode="extract"
                    shift # Consume the option.
                    ;;
                -l|--list) # List mode option.
                    operation_mode="list"
                    shift # Consume the option.
                    ;;
                -t|--target) # Target directory option.
                    if [[ -z "$2" || "$2" == --* ]]; then
                        log_error "Zielverzeichnis fehlt für Option \"-t/--target\"."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    target_directory="$2" # Assign the target directory.
                    shift 2 # Consume option and argument.
                    ;;
                -v|--verbose) # Verbose output option.
                    verbose_output=true
                    shift
                    ;;
                -d|--delete) # Delete after operation option.
                    delete_after_operation=true
                    shift
                    ;;
                -n|--name) # Custom archive name option.
                     if [[ -z "$2" || "$2" == --* ]]; then
                        log_error "Name fehlt für Option \"-n/--name\"."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    custom_archive_name="$2" # Assign custom name.
                    shift 2
                    ;;
                -e|--exclude) # Exclude pattern option.
                    if [[ -z "$2" || "$2" == --* ]]; then
                        log_error "Ausschlussmuster fehlt für Option \"-e/--exclude\"."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    exclude_patterns+=("$2") # Add to array of exclude patterns.
                    shift 2
                    ;;
                -i|--include) # Include pattern option.
                    if [[ -z "$2" || "$2" == --* ]]; then
                        log_error "Einschlussmuster fehlt für Option \"-i/--include\"."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    include_patterns+=("$2") # Add to array of include patterns.
                    shift 2
                    ;;
                # Case for -f/--filter was removed as the 'filter_file' variable was unused (SC2034).
                -j|--jobs) # Number of jobs for parallel processing.
                    if [[ -z "$2" || "$2" == --* ]]; then
                        log_error "Anzahl Jobs fehlt für Option \"-j/--jobs\"."
                        echo "$usage" >&2
                        return 2 # Usage error
                    fi
                    # Validate if jobs is a non-negative integer
                    if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                        log_error "Ungültige Anzahl für Jobs: \"$2\". Muss eine nicht-negative Zahl sein."
                        echo "$usage" >&2
                        return 2 # Usage error
                    fi
                    user_jobs_specification="$2" # Store what the user specified for -j.
                    num_jobs="$2" # Update num_jobs with user-specified value.
                    shift 2
                    ;;
                -p|--password) # Password option.
                    if [[ -z "$2" || "$2" == --* ]]; then # Check for missing password argument.
                        log_error "Passwort fehlt für Option \"-p/--password\"."
                        echo "$usage" >&2
                        return 2 # Usage error.
                    fi
                    archive_password="$2" # Assign password.
                    shift 2
                    ;;
                -h|--help) # Help option.
                    echo "$usage" # Display help message.
                    return 2 # Exit with 2 (convention for help display via option).
                    ;;
                --debug) # Debug mode option.
                    debug_mode=true
                    shift # Consume option.
                    ;;
                --) # End of options marker from getopt.
                    shift # Consume the '--'.
                    # All remaining arguments are considered input files/directories.
                    # If input_files array is still empty (i.e., not populated by alias handling),
                    # assign all remaining positional parameters to it. Quoted "$@".
                    if [[ ${#input_files[@]} -eq 0 ]]; then
                        input_files=("$@") # Assign remaining arguments to input_files.
                    fi
                    break # Exit the while loop as all options have been processed.
                    ;;
                *) # Should not be reached if getopt works correctly.
                    # This is a safeguard for unexpected behavior after getopt processing.
                    log_error "Interner Fehler beim Parsen der Optionen nach getopt: \"$1\""
                    echo "$usage" >&2
                    return 1 # General error.
                    ;;
            esac
        done

        # Final validation checks after parsing all options.
        # Check if compress mode is selected but no compression format is specified.
        if [[ "$operation_mode" == "compress" && -z "$compression_format" ]]; then
            log_error "Kein Kompressionsformat angegeben für Modus Komprimieren."
            # This scenario should ideally be caught by getopt if -c is given without an argument,
            # or by the alias pre-processing if 'pac c' is used without a format.
            # This serves as an additional safeguard.
            echo "$usage" >&2
            return 2 # Usage error.
        fi
        
        # Additional check for alias 'c' usage: ensure format was provided.
        # This might be redundant if the alias pre-processing is robust but acts as a safeguard.
        if [[ "${args_to_parse[0]}" == "-c" && -z "$compression_format" ]]; then
             # This condition implies that 'c' alias was used, converted to '-c', but format was still not captured.
             # The check `[[ ${#args_to_parse[@]} -lt 2 || "${args_to_parse[1]}" == "--"* ]]` is a bit complex here
             # as args_to_parse is not directly available. The primary check above should suffice.
             # However, if an issue is suspected here, more direct checks on original arguments might be needed,
             # or rely on getopt correctly requiring an argument for -c.
             # For now, assuming the previous checks are sufficient.
             : # This specific check might be an over-complication if getopt handles -c arg requirement.
        fi
        return 0 # Successful parsing.
    }

    # Debugging aktivieren, falls --debug übergeben wurde
    # Diese Zeile muss NACH dem Parsen der Argumente stehen.
    # $debug && set -x # Wird später aktiviert, nach dem Parsen

    # Argumente parsen
    # Wichtig: Übergebe die Originalargumente $@ an parse_args, die Funktion kümmert sich um die Aliase
    parse_args "$@"
    local parse_status=$?

    # Debugging aktivieren, NACHDEM `debug_mode` Variable gesetzt wurde by parse_args
    if [[ "$debug_mode" == "true" ]]; then
        set -x
    fi
    
    # Check the return status of parse_args.
    # parse_status meanings:
    #   0: Success
    #   1: General error within parse_args (should be rare with getopt).
    #   2: Usage error (e.g., invalid option, missing argument for an option, -h invoked).
    if [[ "$parse_status" -ne 0 ]]; then
        # If parse_args failed or displayed help (-h), exit the main pac function.
        # Error messages or help text should have already been displayed by parse_args.
        return "$parse_status" 
    fi

    # Check for common system dependencies once after successful argument parsing.
    # This provides early warnings if some tools for certain formats are missing.
    check_dependencies

    # Create the target directory if it doesn't exist.
    # This is done early to catch permission issues before lengthy operations.
    if ! mkdir -p "$target_directory"; then
        log_error "Konnte Zielverzeichnis nicht erstellen: \"$target_directory\". Überprüfe Berechtigungen."
        return 4 # Permission error (oder allgemeiner Fehler beim Erstellen)
    fi
    # Prüfung ob Zielverzeichnis beschreibbar ist (wird später vor Operationen genauer geprüft)
    if [[ ! -w "$target_directory" ]]; then
        log_error "Zielverzeichnis ist nicht beschreibbar: \"$target_directory\""
        return 4 # Permission error
    fi

    # Construct the full output archive path if in compress mode.
    # This path is built from target_directory, custom_archive_name, and compression_format.
    # Ensure paths are handled correctly, especially if target_directory is relative.
    if [[ "$operation_mode" == "compress" ]]; then
        if [[ "$target_directory" != "." && "$target_directory" != "" ]]; then
            case "$target_directory" in
                /*) # Absolute path for target_directory
                    output_archive_path="${target_directory}/${custom_archive_name}.${compression_format}" ;;
                *)  # Relative path for target_directory
                    output_archive_path="$(pwd)/${target_directory}/${custom_archive_name}.${compression_format}" ;;
            esac
        else # target_directory is current directory (.) or was empty (defaulted to .)
            output_archive_path="${custom_archive_name}.${compression_format}"
        fi
        debug_info "Finaler Ausgabepfad für Archiv: \"$output_archive_path\""
    fi

    # Helper function for tar extraction.
    # Parameters:
    #   $1: archive file path
    #   $2: target directory path
    #   $3: specific tar format extension (e.g., "gz", "bz2", "xz", "zst"), or empty for plain .tar
    # Returns:
    #   0 on success.
    #   6 if 'tar' command is not found.
    #   Exit code from 'tar' on other errors.
    extract_tar() {
        local archive_file="$1" # Use more descriptive names
        local target_extract_dir="$2"
        local tar_format_option="$3"
        local tar_exit_code=0
        
        local -a tar_opts=("-x") # Start with extract option
        
        # Add format-specific options for tar
        case "$tar_format_option" in
            "gz") tar_opts+=("-z") ;;    # For .tar.gz
            "bz2") tar_opts+=("-j") ;;   # For .tar.bz2
            "xz") tar_opts+=("-J") ;;    # For .tar.xz
            "zst") tar_opts+=("--zstd") ;; # For .tar.zst
             # No option needed for plain .tar
        esac
        
        # Add verbose option if enabled globally
        if [[ "$verbose_output" == "true" ]]; then
            tar_opts+=("-v")
        fi
        
        # Add archive file and target directory options
        tar_opts+=("-f" "$archive_file" "-C" "$target_extract_dir")
        
        debug_info "Tar command and options: tar ${tar_opts[*]}"
        
        # Execute tar. Its stderr output will go to the script's stderr.
        if ! tar "${tar_opts[@]}"; then
            tar_exit_code=$? # Capture tar's exit code
            if [[ "$tar_exit_code" -eq 127 ]]; then
                log_error "Befehl 'tar' nicht gefunden. Bitte installieren Sie tar."
                return 6 # Dependency not found
            fi
            # The actual error message from tar should already be on stderr.
            # This log_error call provides additional context.
            log_error "tar-Extraktion von '$archive_file' fehlgeschlagen mit Code $tar_exit_code."
            return "$tar_exit_code" # Return tar's specific error code
        fi
        return 0 # Success
    }
    
    # --- Main script logic: dispatch based on operation_mode (compress, list, extract) ---
    
    # --- COMPRESS MODE ---
    if [[ "$operation_mode" == "compress" ]]; then
        # Check if input files for compression are provided
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Eingabedateien für Komprimierung angegeben."
            return 2 # Usage error: no input files for compress mode
        fi

        # Verify all input files/directories exist before starting compression
        local item
        for item in "${input_files[@]}"; do
            if [[ ! -e "$item" ]]; then # -e checks for existence (file, dir, symlink, etc.)
                log_error "Eingabedatei oder -verzeichnis nicht gefunden: $item"
                return 3 # File not found error
            fi
        done

        # Determine archive name if not specified by user (-n option).
        if [[ -z "$custom_archive_name" ]]; then
            if [[ ${#input_files[@]} -eq 1 && -e "${input_files[0]}" ]]; then
                # If one input file, use its basename (removing common extensions).
                custom_archive_name="$(basename "${input_files[0]%.*}")" 
            else
                # For multiple inputs or if the single input doesn't exist (though checked above),
                # generate a timestamped default name.
                custom_archive_name="archive_$(date "+%Y%m%d_%H%M%S")" # Quoted command substitution.
            fi
        fi

        # Re-construct the output_archive_path with the potentially auto-generated custom_archive_name
        if [[ "$target_directory" != "." && "$target_directory" != "" ]]; then
            case "$target_directory" in
                /*) # Absolute path for target_directory
                    output_archive_path="${target_directory}/${custom_archive_name}.${compression_format}" ;;
                *)  # Relative path for target_directory
                    output_archive_path="$(pwd)/${target_directory}/${custom_archive_name}.${compression_format}" ;;
            esac
        else # target_directory is current directory (.) or was empty (defaulted to .)
            output_archive_path="${custom_archive_name}.${compression_format}"
        fi
        
        local output_target_directory # More specific name for this context
        output_target_directory="$(dirname "$output_archive_path")"

        # Ensure output directory exists and is writable
        if [[ ! -d "$output_target_directory" ]]; then
            if ! mkdir -p "$output_target_directory"; then
                log_error "Ausgabeverzeichnis \"$output_target_directory\" konnte nicht erstellt werden."
                return 4 # Permission or path error
            fi
        fi
        if [[ ! -w "$output_target_directory" ]]; then
            log_error "Ausgabeverzeichnis \"$output_target_directory\" ist nicht beschreibbar."
            return 4 # Permission error
        fi
        
        # Check available disk space (check_space logs its own errors and returns 1 on failure)
        check_space "${input_files[@]}" "$output_target_directory" || return 1 

        log_info "Erstelle Archiv: \"$output_archive_path\""
        
        # Determine effective number of jobs for tools
        # If user_jobs_specification is empty (user did not use -j), we want tools to use all cores (typically by passing 0 or specific flags)
        # If user specified -j N, then num_jobs variable holds N.
        local effective_jobs
        if [[ -z "$user_jobs_specification" ]]; then # User did not specify -j.
            effective_jobs=0 # Means "all cores" for xz, zstd, 7z (usually)
        else
            effective_jobs="$num_jobs" # Use the number specified by the user
        fi
        debug_info "Effektive Anzahl Jobs für Tools: $effective_jobs (0 = alle Kerne, wenn vom Tool unterstützt)"

        local cmd_exec_code=0
        case "$compression_format" in
            tar)
                tar -c${verbose_output:+v}f "$output_archive_path" "${input_files[@]}"
                cmd_exec_code=$?
                ;;
            tar.gz)
                # pigz can be used for parallel gzip if available and desired, but tar calls gzip by default.
                # For standard tar, gzip is usually single-threaded.
                tar -cz${verbose_output:+v}f "$output_archive_path" "${input_files[@]}"
                cmd_exec_code=$?
                ;;
            tar.bz2)
                # pbzip2 can be used for parallel bzip2. Similar to pigz.
                tar -cj${verbose_output:+v}f "$output_archive_path" "${input_files[@]}"
                cmd_exec_code=$?
                ;;
            tar.xz)
                # XZ_OPT="-T0" uses all cores. -TN uses N threads.
                XZ_OPT="-T${effective_jobs}" tar -cJ${verbose_output:+v}f "$output_archive_path" "${input_files[@]}"
                cmd_exec_code=$?
                ;;
            tar.zst)
                # For zstd with tar: --zstd:threads=N. Level is separate.
                # ZSTD_CLEVEL default is 3, which is fast.
                local zstd_level=3 
                debug_info "ZSTD Kompressionslevel: $zstd_level"
                tar --zstd --zstd:level="$zstd_level" --zstd:threads="$effective_jobs" \
                    -c${verbose_output:+v}f "$output_archive_path" \
                    "${input_files[@]}"
                cmd_exec_code=$?
                ;;
            zip)
                local zip_opts=("-r") # -r for recursive
                # Apply verbosity related options for zip
                if [[ "$verbose_output" != "true" ]]; then # Make zip quiet if not verbose
                    zip_opts+=("-q")
                fi
                
                if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
                    for pattern in "${exclude_patterns[@]}"; do zip_opts+=(-x "$pattern"); done
                fi
                # Note: zip requires paths relative to current dir for excludes to work well from patterns.txt
                # For simplicity, current implementation assumes patterns are directly usable by zip.
                # Using subshell to ensure `cd` doesn't affect the main script's CWD.
                (cd "$PWD" && zip "${zip_opts[@]}" "$output_archive_path" "${input_files[@]}")
                cmd_exec_code=$?
                ;;
            7z)
                local sz_opts=("a") # Add files to archive
                if [[ -n "$archive_password" ]]; then sz_opts+=("-p$archive_password"); fi # Use renamed variable
                
                # 7z threading: -mmtN (N cores), -mmt (all available).
                # If effective_jobs is 0 (meaning user wants all cores), pass -mmt. Otherwise -mmtN.
                if [[ "$effective_jobs" -eq 0 ]]; then
                    sz_opts+=("-mmt") # Use all available cores
                    debug_info "7z: Verwende alle verfügbaren Kerne (-mmt)"
                else
                    sz_opts+=("-mmt${effective_jobs}") # Use specified number of cores
                    debug_info "7z: Verwende $effective_jobs Kern(e) (-mmt${effective_jobs})"
                fi
                # Consider -mx (compression level) if speed/ratio choice is added later. Default is -mx5.
                # Example: sz_opts+=("-mx1") for faster compression.
                7z "${sz_opts[@]}" "$output_archive_path" "${input_files[@]}"
                cmd_exec_code=$?
                ;;
            *)
                log_error "Nicht unterstütztes Kompressionsformat: \"$compression_format\""
                return 5 # Invalid format error
                ;;
        esac

        if [[ "$cmd_exec_code" -eq 127 ]]; then
            log_error "Benötigtes Werkzeug für Format \"$compression_format\" nicht gefunden. (Exit-Code: 127)"
            # Attempt to remove potentially incomplete archive file
            [[ -f "$output_archive_path" ]] && rm "$output_archive_path" 2>/dev/null
            return 6 # Dependency not found
        elif [[ "$cmd_exec_code" -ne 0 ]]; then
            log_error "Fehler beim Erstellen des Archivs \"$output_archive_path\" (Werkzeug-Exit-Code: $cmd_exec_code)."
            [[ -f "$output_archive_path" ]] && rm "$output_archive_path" 2>/dev/null
            return 1 # General error from the compression tool
        fi
        
        log_success "Archiv erfolgreich erstellt: \"$output_archive_path\""
        if [[ "$delete_after_operation" == "true" ]]; then
            log_info "Lösche Originaldateien..."
            for file_to_delete in "${input_files[@]}"; do
                if [[ -e "$file_to_delete" ]]; then # Check existence again before deleting
                    if rm -rf "$file_to_delete"; then # -rf to handle files and dirs
                        debug_info "Original gelöscht: \"$file_to_delete\""
                    else
                        log_warning "Konnte Original nicht löschen: \"$file_to_delete\""
                        # Non-fatal, so don't change exit code
                    fi
                fi
            done
        fi
        return 0 # Success for compression
    elif [[ "$operation_mode" == "list" ]]; then
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Archive für Auflistung angegeben."
            return 2 # Usage error
        fi

        local file_not_found_flag=false
        local tool_not_found_flag=false
        local invalid_format_flag=false
        local operation_failed_flag=false
        local overall_rc=0 # Default success

        for file in "${input_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                log_error "Archiv nicht gefunden: \"$file\""
                file_not_found_flag=true
                continue # Process next file
            fi
            
            log_info "Inhalt von: \"$file\""
            local list_cmd_exit_code=0 # Reset for each file
            
            case "$file" in
                *.tar) tar -tf "$file" || list_cmd_exit_code=$? ;;
                *.tar.gz|*.tgz) tar -tzf "$file" || list_cmd_exit_code=$? ;;
                *.tar.bz2|*.tbz2) tar -tjf "$file" || list_cmd_exit_code=$? ;;
                *.tar.xz|*.txz) tar -tJf "$file" || list_cmd_exit_code=$? ;;
                *.tar.zst) tar --zstd -tf "$file" || list_cmd_exit_code=$? ;;
                *.zip) unzip -l "$file" || list_cmd_exit_code=$? ;;
                *.7z) 7z l "$file" || list_cmd_exit_code=$? ;;
                *) 
                    log_error "Nicht unterstütztes Archivformat für Auflistung: \"$file\""
                    invalid_format_flag=true
                    list_cmd_exit_code=-1 # Internal code to signify invalid format handled by us
                    ;;
            esac

            if [[ "$list_cmd_exit_code" -ne 0 ]]; then
                if [[ "$list_cmd_exit_code" -eq 127 ]]; then
                    log_error "Benötigtes Werkzeug zum Auflisten von \"$file\" nicht gefunden."
                    tool_not_found_flag=true
                elif [[ "$list_cmd_exit_code" -eq -1 ]]; then 
                    # This was our internal code for invalid_format_flag, already set
                    : 
                else
                    # Log specific error from the tool if it wasn't a "command not found"
                    log_error "Fehler beim Auflisten des Inhalts von \"$file\" (Werkzeug-Exit-Code: $list_cmd_exit_code)."
                    operation_failed_flag=true
                fi
            fi
        done

        # Determine overall return code based on priority
        if [[ "$file_not_found_flag" == "true" ]]; then overall_rc=3;
        elif [[ "$tool_not_found_flag" == "true" ]]; then overall_rc=6;
        elif [[ "$invalid_format_flag" == "true" ]]; then overall_rc=5;
        elif [[ "$operation_failed_flag" == "true" ]]; then overall_rc=1;
        fi
        
        return $overall_rc
    else
        # Extract mode
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Archive für Extraktion angegeben."
            return 2 # Usage error
        fi
        
        local file_not_found_flag=false
        local permission_error_flag=false
        local tool_not_found_flag=false
        local invalid_format_flag=false
        local operation_failed_flag=false
        local overall_rc=0 # Default success

        for file in "${input_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                log_error "Archiv nicht gefunden für Extraktion: \"$file\""
                file_not_found_flag=true
                continue # Process next file
            fi
            
            debug_info "Extrahiere: \"$file\" nach \"$target_directory\""
            local current_op_exit_code=0 # Reset for each file/operation

            # Check target directory writability before attempting extraction for this file
            # This check was already done globally, but an extra check here per file can be useful
            # if target_directory could somehow change or become non-writable during the loop.
            # However, the global check at the beginning should suffice.
            # For now, we assume $target_directory is writable based on initial check.
            # Individual tools like unzip/7z might have their own specific permission issues for subdirs.

            case "$file" in
                *.tar) extract_tar "$file" "$target_directory" "" || current_op_exit_code=$? ;;
                *.tar.gz|*.tgz) extract_tar "$file" "$target_directory" "gz" || current_op_exit_code=$? ;;
                *.tar.bz2|*.tbz2) extract_tar "$file" "$target_directory" "bz2" || current_op_exit_code=$? ;;
                *.tar.xz|*.txz) extract_tar "$file" "$target_directory" "xz" || current_op_exit_code=$? ;;
                *.tar.zst) extract_tar "$file" "$target_directory" "zst" || current_op_exit_code=$? ;;
                *.zip) 
                    local unzip_opts=()
                    # Add verbosity option for unzip if verbose_output is true.
                    # Unzip's -q (quiet) is the opposite of verbose, so only add -v if verbose.
                    # By default, unzip is somewhat verbose. If pac -v is not used, we make unzip quiet.
                    if [[ "$verbose_output" != "true" ]]; then
                        unzip_opts+=("-q")
                    fi
                    # Ensure target_directory exists (already done globally, but good practice for direct tool calls)
                    mkdir -p "$target_directory"
                    if [[ ! -w "$target_directory" ]]; then # Check again, specific to this operation
                        log_error "Zielverzeichnis \"$target_directory\" ist nicht beschreibbar für unzip von \"$file\"."
                        current_op_exit_code=4 # Permission error for this specific operation
                    else
                        unzip "${unzip_opts[@]}" "$file" -d "$target_directory" || current_op_exit_code=$?
                    fi
                    ;;
                *.7z) 
                    local sz_opts=("x") # Extract
                    if [[ -n "$archive_password" ]]; then sz_opts+=("-p$archive_password"); fi # Use renamed variable
                    # Ensure target_directory exists
                    mkdir -p "$target_directory"
                     if [[ ! -w "$target_directory" ]]; then # Check again
                        log_error "Zielverzeichnis \"$target_directory\" ist nicht beschreibbar für 7z von \"$file\"."
                        current_op_exit_code=4 # Permission error
                    else
                        # 7z needs -o directly followed by the directory, no space.
                        sz_opts+=("$file" "-o${target_directory}") 
                        7z "${sz_opts[@]}" || current_op_exit_code=$?
                    fi
                    ;;
                *) 
                    log_error "Nicht unterstütztes Archivformat für Extraktion: \"$file\""
                    invalid_format_flag=true # Set flag for overall error reporting
                    current_op_exit_code=-1 # Internal code for invalid format
                    ;;
            esac
            
            if [[ "$current_op_exit_code" -eq 0 ]]; then
                log_success "Erfolgreich extrahiert: \"$file\" nach \"$target_directory\""
                if [[ "$delete_after_operation" == "true" && -f "$file" ]]; then
                    if rm "$file"; then 
                        debug_info "Originaldatei gelöscht: \"$file\""
                    else 
                        log_warning "Konnte Originaldatei \"$file\" nicht löschen."
                        # This is a warning, does not make the whole operation fail
                    fi
                fi
            else
                # Update flags based on current_op_exit_code for overall error reporting
                if [[ $current_op_exit_code -eq 127 ]] || [[ $current_op_exit_code -eq 6 ]]; then
                    # 127 from direct zip/7z, 6 from extract_tar
                    log_error "Benötigtes Werkzeug zum Extrahieren von \"$file\" nicht gefunden."
                    tool_not_found_flag=true
                elif [[ "$current_op_exit_code" -eq 4 ]]; then
                    # This would be from our explicit check for unzip/7z target dir writability
                    # extract_tar itself doesn't return 4, it would be a tool error (e.g. 1 or 2 from tar)
                    log_error "Berechtigungsfehler bei Extraktion von \"$file\" nach \"$target_directory\"."
                    permission_error_flag=true
                elif [[ "$current_op_exit_code" -eq -1 ]]; then 
                    # Our internal code for invalid_format_flag, flag already set by case.
                    : 
                else
                    # General error from the extraction tool (tar, unzip, 7z)
                    # extract_tar already logs its specific error message.
                    # For zip/7z, we might need a generic message if they haven't logged one.
                    if [[ ! "$file" == *.tar* ]]; then # tar errors are logged in extract_tar
                         log_error "Fehler beim Extrahieren von \"$file\" (Werkzeug-Exit-Code: $current_op_exit_code)."
                    fi
                    operation_failed_flag=true
                fi
            fi
        done # End of for loop iterating through input_files

        # Determine overall return code for extract mode based on priority of flags
        if [[ "$file_not_found_flag" == "true" ]]; then overall_rc=3;
        elif [[ "$permission_error_flag" == "true" ]]; then overall_rc=4;
        elif [[ "$tool_not_found_flag" == "true" ]]; then overall_rc=6;
        elif [[ "$invalid_format_flag" == "true" ]]; then overall_rc=5;
        elif [[ "$operation_failed_flag" == "true" ]]; then overall_rc=1;
        fi
        
        return $overall_rc
    fi

    # Debugging deaktivieren
    # Deactivate debug mode (set +x) if it was enabled, before exiting the function.
    if [[ "$debug_mode" == "true" ]]; then
        set +x
    fi

    # This part should ideally not be reached if modes (compress, list, extract) handle their returns.
    # If execution reaches here, it implies an unhandled case or logic error in the mode blocks.
    log_error "Pac function reached an unexpected state at the end. This indicates a logic flow issue."
    log_error "Mode was: \"$operation_mode\". Last operation status might be relevant."
    return 1 # General error for unexpected fallthrough
}

# Vor der Kompression
check_space() {
    local total_size_kb=0
    local item_path
    # The last argument is the target directory, all previous are input files/dirs
    local num_args=$#
    local target_dir_for_space="${!num_args}" # Last argument
    
    for ((i=1; i<num_args; i++)); do
        item_path="${!i}"
        if [[ -e "$item_path" ]]; then
            # du -sk returns size in kilobytes
            local size_kb
            size_kb="$(du -sk "$item_path" | awk '{print $1}')" # Quoted command substitution
            if [[ -n "$size_kb" && "$size_kb" -gt 0 ]]; then
                total_size_kb=$((total_size_kb + size_kb))
            fi
        fi
    done
    
    # Estimate required space (very rough estimate, can be improved)
    local estimated_required_kb=$total_size_kb
    # Use the script-level variable compression_format here
    case "$compression_format" in
        # Highly compressible formats might take less space
        tar.gz|zip) estimated_required_kb=$((total_size_kb / 2)) ;; # Guess 50% compression
        tar.bz2|tar.xz|tar.zst) estimated_required_kb=$((total_size_kb / 3)) ;; # Guess 66% compression
        # tar itself doesn't compress
        tar) estimated_required_kb=$total_size_kb ;;
        *) estimated_required_kb=$total_size_kb ;; # Default if format unknown
    esac
    
    # Get available space in kilobytes in the target directory's filesystem
    local available_kb
    available_kb=$(df -kP "$target_dir_for_space" | awk 'NR==2 {print $4}')
    
    if [[ -z "$available_kb" ]]; then
        log_warning "Konnte verfügbaren Speicherplatz in '$target_dir_for_space' nicht ermitteln."
        return 0 # Non-fatal, proceed with compression
    fi

    debug_info "Geschätzter benötigter Speicherplatz: ${estimated_required_kb}KB"
    debug_info "Verfügbarer Speicherplatz in '$target_dir_for_space': ${available_kb}KB"

    if [[ $estimated_required_kb -gt $available_kb ]]; then
        log_error "Nicht genügend Speicherplatz in '$target_dir_for_space'. Benötigt ca. ${estimated_required_kb}KB, verfügbar: ${available_kb}KB."
        return 1 # Error: insufficient space
    fi
    return 0 # Success: sufficient space
}

    # Autocompletion function for pac.
    # Provides context-sensitive suggestions for options and arguments when Tab is pressed.
_pac_autocomplete() {
    # Standard Bash completion variables used by this function:
    # COMP_WORDS: An array containing the individual words in the current command line.
    # COMP_CWORD: The index of the current word being completed in the COMP_WORDS array.
    # COMPREPLY:  An array variable from which Bash reads the possible completions.
    
    # Declare local variables for clarity.
    # 'cur' holds the current word being completed.
    # 'prev' holds the word immediately preceding the current word.
    local cur prev opts formats
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Define the full list of command-line options and supported formats for pac.
    # The '-f' option (and '--filter') has been removed from 'opts' as it's no longer processed by pac.sh.
    opts="-c --compress -x --extract -l --list -t --target -n --name -d --delete -v --verbose -h --help --debug -e --exclude -i --include -j --jobs -p --password"
    formats="tar tar.gz tar.bz2 tar.xz tar.zst zip 7z"
    
    # Use mapfile for safer assignment from compgen output to COMPREPLY array (addresses SC2207).
    # mapfile -t <array> reads lines from standard input into the array.
    # < <(command) is process substitution, treating command output as if it were a file.

    # If completing the first argument right after the 'pac' command itself.
    if [[ "$COMP_CWORD" -eq 1 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
        return 0 # Indicate completion handling is done for this case.
    fi

    # Provide context-specific completions based on the 'prev' (previous) argument.
    case "$prev" in
        -c|--compress)
            # If the previous option was -c or --compress, suggest available compression formats.
            mapfile -t COMPREPLY < <(compgen -W "$formats" -- "$cur")
            ;;
        -x|--extract|-l|--list)
            # If extracting or listing, suggest existing files, particularly those with common archive extensions.
            # The glob pattern `!*.@(...)` filters for files matching these extensions.
            # Extended globbing `*.@(pattern1|pattern2)` needs `shopt -s extglob` if not already set,
            # but `compgen -X` might handle this internally or rely on calling shell's settings.
            # For maximum portability within the compgen pattern, simpler patterns are safer if extglob isn't guaranteed.
            # However, this specific pattern is common in completion scripts.
            mapfile -t COMPREPLY < <(compgen -f -X '!*.@(tar|gz|tgz|bz2|tbz2|xz|txz|zst|zip|7z|RAR|ARJ|DEB|RPM|iso|img|apk|jar)' -- "$cur")
            ;;
        -t|--target)
            mapfile -t COMPREPLY < <(compgen -d -- "$cur") # Suggest directories only.
            ;;
        -e|--exclude|-i|--include) # Note: -f option was removed.
            mapfile -t COMPREPLY < <(compgen -f -- "$cur") # Suggest files or directories for patterns.
            ;;
        -n|--name)
            COMPREPLY=() # No specific suggestions for archive name; user typically types this freely.
            ;;
        -j|--jobs)
            # Suggest '0' (for all cores, if supported by the tool), common core counts,
            # and a sequence up to the number of available processors (or a fallback).
            local core_suggestion="0 1 2 4 8" # Common/sensible job counts.
            local detected_cores
            # Quoted command substitution for safety.
            if detected_cores="$(nproc 2>/dev/null)"; then # Try to get actual core count.
                 core_suggestion+=" $(seq 1 "$detected_cores")" # Add sequence from 1 to detected_cores. Quoted.
            else
                 core_suggestion+=" $(seq 1 8)" # Fallback if nproc is not available.
            fi
            mapfile -t COMPREPLY < <(compgen -W "$core_suggestion" -- "$cur")
            ;;
        -p|--password)
            COMPREPLY=() # No suggestions for password input for security reasons.
            ;;
        *)
            # Default completion behavior if no specific context matches above.
            # If the current word starts with a dash ('-'), assume it's an option and suggest from 'opts'.
            if [[ "$cur" == -* ]]; then
                mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
            else
                # Otherwise, suggest files and directories (e.g., for input files for compress/extract/list).
                mapfile -t COMPREPLY < <(compgen -f -- "$cur")
            fi
            ;;
    esac
    return 0 # Indicate completion handling is done.
}
# Register the _pac_autocomplete function to handle programmable completions for the 'pac' command.
# This makes the defined suggestions available when a user presses Tab after typing 'pac '.
complete -F _pac_autocomplete pac
