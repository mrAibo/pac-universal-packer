
# PAC - Universal Packer

PAC (Pack And Compress) is a versatile Bash tool for easy compression and extraction of archives in various formats. It simplifies the use of complex archiving commands and provides a unified interface for all common archive formats.

## Features

- **Unified interface** for all common archive formats
- **Automatic format detection** during extraction
- **Parallel processing** with automatic CPU core detection
- **Pattern-based inclusions/exclusions** for precise archiving
- **Progress display** for lengthy operations
- **Password protection** for supported formats
- **Shell completion** for easy operation

## Installation

### Prerequisites

- Bash 4.0 or higher
- Depending on the formats you want to use: `tar`, `gzip`, `bzip2`, `xz`, `zstd`, `zip`, `unzip`, `7z`

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mrAibo/pac-universal-packer.git
   ```

2. Change to the directory:
   ```bash
   cd pac-universal-packer
   ```

3. Make the script executable:
   ```bash
   chmod +x pac.sh
   ```

4. (Optional) Create a symbolic link for system-wide access:
   ```bash
   sudo ln -s $(pwd)/pac.sh /usr/local/bin/pac
   ```

5. (Optional) Add the function to your `.bashrc` or `.zshrc`:
   ```bash
   echo "source $(pwd)/pac.sh" >> ~/.bashrc
   ```

## Quick Start

### Compression

```bash
# Simple compression (creates file.zip)
pac -c zip file.txt

# Multiple files with custom name
pac -c tar.gz -n backup src/ config/ docs/

# With exclusion patterns
pac -c zip -e "*.tmp" -e "node_modules/" src/
```


### Extraction

```bash
# Simple extraction
pac archive.zip

# Extract to a custom target directory
pac -t output/ archive.tar.gz

# Extract multiple archives
pac archive1.zip archive2.tar.gz
```


### Listing

```bash
# Display archive contents
pac -l archive.zip
```


## Syntax

```
pac [OPTIONS] file1 [file2 ...]
```


## Options

| Option | Long form | Description |
|--------|-----------|-------------|
| `-c FORMAT` | `--compress FORMAT` | Compression mode (format: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z) |
| `-x` | `--extract` | Extraction mode (default) |
| `-l` | `--list` | Display archive contents |
| `-v` | `--verbose` | Show detailed progress |
| `-t DIR` | `--target DIR` | Specify target directory |
| `-d` | `--delete` | Delete original file(s) after operation |
| `-e PATTERN` | `--exclude PATTERN` | Exclude files/directories matching pattern |
| `-i PATTERN` | `--include PATTERN` | Include only files/directories matching pattern |
| `-f FILE` | `--filter FILE` | Read include/exclude patterns from file |
| `-n NAME` | `--name NAME` | Custom archive name (without extension) |
| `-j NUM` | `--jobs NUM` | Number of processes for parallel compression |
| `-p PASS` | `--password PASS` | Encryption with password (only for zip and 7z) |
| `--debug` | | Enable debug output |
| `-h` | `--help` | Show help message |

## Supported Formats

### Compression
- tar.gz (gzip)
- tar.bz2 (bzip2)
- tar.xz (xz)
- tar.zst (zstd)
- zip
- 7z

### Extraction
All of the above plus their alias names (e.g., .tgz for .tar.gz)

## Advanced Usage

### Pattern-based Inclusions/Exclusions

```bash
# Exclude files
pac -c zip -e "*.log" -e "*.tmp" src/

# Include only specific files
pac -c tar.gz -i "*.txt" -i "*.md" docs/

# Use complex patterns from file
echo "+*.txt" > patterns.txt
echo "+*.md" >> patterns.txt
echo "-*test*" >> patterns.txt
pac -c zip -f patterns.txt docs/
```


### Pattern File Format

```
# Comments start with a hash
+*.txt        # Include text files
+docs/*.md    # Include markdown files in docs directory
-*.tmp        # Exclude temporary files
-build/       # Exclude build directory
```


### Multithreading

```bash
# Use specific number of threads
pac -c tar.xz -j 4 large_directory/

# Automatic thread detection (default behavior)
pac -c tar.xz large_directory/
```


### Password Protection

```bash
# Protect with password (for zip and 7z)
pac -c zip -p "my_password" sensitive_data/

# Interactive password entry
pac -c 7z -p "" confidential_files/
```


## Use Cases

### Project Backup

```bash
pac -n project-backup -c zip -e "node_modules/" -e "*.log" -e "tmp/" src/
```


### Document Archiving

```bash
pac -c zip -i "*.pdf" -i "*.doc" -i "*.txt" -n documents docs/
```


### Source Code Backup with Cleanup

```bash
pac -t backups/ -n src-v1.0 -c tar.gz -d -e "*.tmp" -e "build/" src/
```


### Multi-Directory Backup

```bash
pac -c tar.gz -n full-backup -t backups/ src/ docs/ config/
```


## Tips

- All options can be specified in any order.
- Archive names are based on input names if `-n` is not used.
- Multiple inputs without `-n` create 'archive.*'.
- Use `-v` for detailed progress information.
- The `-j` option overrides automatic thread detection.
- Pattern files support both inclusion (`+`) and exclusion (`-`) patterns.

## Troubleshooting

### Common Issues

- **"Command not found" error**: Ensure all required tools are installed (tar, gzip, etc.).
- **Extraction fails**: Check the archive format and ensure it's not corrupted.
- **No files found**: Check the inclusion/exclusion patterns and paths.

### Debug Mode

Use `--debug` for detailed output:

```bash
pac --debug -c zip my_files/
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch: `git checkout -b my-new-feature`
3. Run tests before creating a pull request
4. Create a pull request with a clear description of your changes

## License

This project is licensed under the GNU GPL v3 License.
