# PAC - Pack And Compress

## Overview

PAC (Pack And Compress) is a versatile command-line tool for simplifying archive compression and extraction tasks on Linux and macOS systems. It provides a unified interface for various common archive formats, supports different operational modes (compress, extract, list), and offers a range of options for customization.

## Features

*   **Multiple Archive Formats**:
    *   Compression: `tar`, `tar.gz` (tgz), `tar.bz2` (tbz2), `tar.xz` (txz), `tar.zst`, `zip`, `7z`.
    *   Extraction & Listing: Auto-detects and supports `tar`, `tar.gz` (tgz), `tar.bz2` (tbz2), `tar.xz` (txz), `tar.zst`, `zip`, `7z`.
*   **Operational Modes**:
    *   Compress (`-c`): Create archives.
    *   Extract (`-x` or default): Extract contents from archives.
    *   List (`-l`): List contents of archives.
*   **Customization**:
    *   Custom archive naming (`-n`).
    *   Specify target directory for output (`-t`).
    *   Delete original files/archives after successful operation (`-d`).
    *   Exclude patterns for filtering files during compression (`-e`). (Note: `-i, --include` is parsed but not fully implemented for all archivers).
    *   Password protection for `zip` and `7z` formats (`-p`).
*   **Performance**:
    *   Parallel processing for `.tar.xz`, `.tar.zst`, and `7z` compression using available CPU cores (`-j`).
*   **Usability**:
    *   Verbose mode (`-v`) for detailed output.
    *   Debug mode (`--debug`) for troubleshooting.
    *   Simple aliases for common operations (e.g., `pac c zip ...`).
    *   Bash autocompletion for commands and options.
    *   Comprehensive help message (`-h`).
    *   Color-coded log messages for better readability.

## Requirements

The script relies on several external tools that must be installed on your system for full functionality with all supported formats:

*   `bash` (typically version 4.0 or newer for `mapfile` in autocompletion)
*   `getopt` (GNU version, usually standard on Linux)
*   `tar`
*   `gzip`
*   `bzip2`
*   `xz` (for `.tar.xz`)
*   `zstd` (for `.tar.zst`)
*   `zip` and `unzip` (for `.zip`)
*   `7z` (p7zip package, for `.7z`)
*   `nproc` (for determining default number of jobs, part of coreutils)
*   `pv` (Pipe Viewer - checked by `check_dependencies` but not actively used in current operations; may be for future features or was part of an earlier one).

Most of these are standard on modern Linux distributions. You can typically install them using your system's package manager (e.g., `apt-get`, `yum`, `dnf`, `pacman`, `brew`).

## Installation/Setup

1.  **Download `pac.sh`**:
    Obtain the `pac.sh` script file.

2.  **Make it Executable**:
    ```bash
    chmod +x pac.sh
    ```

3.  **Place it in your PATH (Recommended)**:
    For easy access from any directory, move `pac.sh` to a directory included in your system's `PATH` environment variable. For example:
    ```bash
    sudo mv pac.sh /usr/local/bin/pac
    ```
    Alternatively, you can create a symbolic link:
    ```bash
    sudo ln -s /path/to/your/pac.sh /usr/local/bin/pac
    ```

4.  **Bash Autocompletion Setup**:
    The script includes a bash autocompletion function (`_pac_autocomplete`). To enable it:
    *   **Option A (Sourcing on demand)**: Source the script when you want to use autocompletion in your current session:
        ```bash
        source /path/to/your/pac.sh
        # or if it's in your PATH and named 'pac'
        source $(which pac)
        ```
    *   **Option B (Automatic on login)**: Add the sourcing command to your shell's startup file (e.g., `~/.bashrc` or `~/.bash_profile`):
        ```bash
        echo 'source /path/to/your/pac.sh' >> ~/.bashrc
        # Then, either restart your shell or source the .bashrc manually for the current session:
        source ~/.bashrc
        ```
    This will allow you to use Tab completion for `pac` commands, options, and file/directory arguments.

## Usage

### Syntax

**Standard Mode/Option Syntax:**
```
pac [MODE] [OPTIONS] file1 [file2 ...]
```

**Alias Syntax (Shortcuts):**
```
pac [ALIAS] [format_if_compressing] file1 [file2 ...]
```
Supported aliases:
*   `c FORMAT`: Equivalent to `pac -c FORMAT`
*   `x`: Equivalent to `pac -x`
*   `l`: Equivalent to `pac -l`

### Main Modes

*   **Compress**: `pac -c FORMAT [OPTIONS] file_or_dir1 [file_or_dir2 ...]`
    *   Creates an archive of the specified format from the input files/directories.
*   **Extract**: `pac [OPTIONS] archive1 [archive2 ...]`
    *   This is the **default mode** if no other mode (`-c`, `-l`) is specified.
    *   Extracts contents of the given archive(s). Format is auto-detected.
*   **List**: `pac -l [OPTIONS] archive1 [archive2 ...]`
    *   Lists the contents of the specified archive(s).

### Detailed Options Table

| Short Option | Long Option        | Argument   | Description                                                                 |
|--------------|--------------------|------------|-----------------------------------------------------------------------------|
| `-c`         | `--compress`       | `FORMAT`   | **Compress mode**. Requires a format (e.g., `zip`, `tar.gz`).               |
| `-x`         | `--extract`        |            | **Extract mode**. Default if no other mode is given.                        |
| `-l`         | `--list`           |            | **List mode**. Shows archive contents.                                      |
| `-t`         | `--target`         | `DIRECTORY`| Specify target directory for output. Default: current directory.            |
| `-n`         | `--name`           | `FILENAME` | Custom archive name (without extension).                                    |
| `-d`         | `--delete`         |            | Delete original file(s)/archive(s) after successful operation.             |
| `-v`         | `--verbose`        |            | Enable verbose output for detailed progress.                                |
| `-h`         | `--help`           |            | Show the comprehensive help message and exit.                               |
| `--debug`    |                    |            | Enable debug output (`set -x`) for troubleshooting.                         |
| `-e`         | `--exclude`        | `PATTERN`  | Exclude files/directories matching PATTERN (compression). Use multiple times. |
| `-i`         | `--include`        | `PATTERN`  | Include only files/directories matching PATTERN (compression). (Note: Limited support by some archivers) |
| `-j`         | `--jobs`           | `NUM`      | Number of processor cores for parallel compression (e.g., for xz, zstd, 7z). |
| `-p`         | `--password`       | `PASS`     | Set password for encryption (zip and 7z only).                              |

*Note: The `-f, --filter FILE` option has been removed from the script.*

## Examples

### Basic Compression

*   Compress `mydoc.txt` to `mydoc.zip`:
    ```bash
    pac -c zip mydoc.txt
    ```
*   Compress `my_project/` directory to `my_project.tar.gz`:
    ```bash
    pac -c tar.gz my_project/
    ```
*   Use alias to compress `important_docs/` to `important_docs.7z` (7z chosen by alias):
    ```bash
    pac c 7z important_docs/
    ```
*   Compress multiple files into `archive_data.tar.bz2`:
    ```bash
    pac -c tar.bz2 file1.txt report.doc image.png
    ```

### Basic Extraction

*   Extract `archive.zip` to the current directory (extract is default mode):
    ```bash
    pac archive.zip
    ```
*   Explicitly use extract mode for `backup.tar.gz`:
    ```bash
    pac -x backup.tar.gz
    ```
*   Use alias for extraction:
    ```bash
    pac x old_stuff.7z
    ```

### Listing Archive Contents

*   List contents of `my_archive.tar.zst`:
    ```bash
    pac -l my_archive.tar.zst
    ```
*   Use alias for listing:
    ```bash
    pac l project_backup.zip
    ```

### Custom Naming and Targeting

*   Compress `file.txt` to `archives/backup_manual.zip`:
    ```bash
    pac -c zip -t archives/ -n backup_manual file.txt
    ```
*   Extract `my_archive.tar` to `extracted_files/` directory:
    ```bash
    pac -t extracted_files/ my_archive.tar
    ```

### Deleting Originals

*   Compress `logs/` directory to `logs.tar.gz` and delete `logs/` afterwards:
    ```bash
    pac -c tar.gz -d logs/
    ```
*   Extract `data.zip` and delete the `data.zip` archive afterwards:
    ```bash
    pac -d data.zip
    ```

### Filtering during Compression

*   Compress `project/` excluding all `.tmp` files and the `build/` directory into `project.zip`:
    ```bash
    pac -c zip -e "*.tmp" -e "build/" project/
    ```
*   Compress `documents/` including only PDF and DOCX files into `docs.tar.gz` (note: include patterns might not be fully supported by all archivers):
    ```bash
    pac -c tar.gz -i "*.pdf" -i "*.docx" documents/
    ```

### Advanced Compression

*   Compress `large_dataset/` to `backup.tar.xz` using 4 parallel jobs and custom name `backup`:
    ```bash
    pac -c tar.xz -j 4 -n backup large_dataset/
    ```
*   Create a password-protected 7z file:
    ```bash
    pac -c 7z -p "YourSecretPassword" sensitive_files/
    ```

### Combining Options

*   Compress `src_code/` into `release_v1.tar.zst` in the `../builds` directory, using all available cores, and show verbose output:
    ```bash
    pac -c tar.zst -t ../builds -n release_v1 -j 0 -v src_code/
    ```

## Exit Codes

The script uses the following exit codes:

*   `0`: Success
*   `1`: General error (e.g., tool failure during compress/extract)
*   `2`: Usage error (e.g., invalid option, missing argument)
*   `3`: Input file / archive not found
*   `4`: Permission error (e.g., cannot create/write to target directory)
*   `5`: Invalid or unsupported archive format for the operation
*   `6`: Required dependency (tool like tar, gzip) not found

## Troubleshooting/Tips

*   If operations fail, ensure all required tools (see "Requirements") are installed and accessible in your `PATH`.
*   Use the `--debug` option to see the exact commands being executed by `pac.sh`, which can help diagnose issues.
*   When using exclude (`-e`) or include (`-i`) patterns, ensure they are quoted to prevent shell expansion before `pac.sh` processes them.
*   For extraction, `pac.sh` auto-detects the format. If you have an archive with an unusual or missing extension, it might fail.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs, feature requests, or improvements.

## License

This script is released under the MIT License. See the `LICENSE` file for details.
