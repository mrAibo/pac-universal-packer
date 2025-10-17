Hier ist das erweiterte README mit allen neuen Features:

```markdown
# PAC - Universal Packer

PAC (Pack And Compress) is a versatile, user-friendly Bash tool for easy compression and extraction of archives in various formats. It simplifies complex archiving commands and provides a modern, unified interface with interactive menus, progress bars, and smart automation.

## ✨ Features

### Core Features
- **🎯 Unified interface** for all common archive formats
- **🔍 Automatic format detection** during extraction
- **⚡ Parallel processing** with automatic CPU core detection
- **📊 Real-time progress bars** using `pv` (Pipe Viewer)
- **🎨 Color-coded output** with Unicode icons for better readability
- **🤖 Interactive mode** for guided operations
- **🛡️ Smart confirmations** for dangerous operations
- **🔐 Password protection** for zip and 7z formats
- **🎯 Pattern-based inclusions/exclusions** for precise archiving
- **✅ Dry-run mode** to preview operations without executing
- **🔕 Quiet mode** for script automation
- **💻 Shell completion** for easy operation
- **📈 Detailed statistics** showing sizes, compression ratios, and time

### User Experience
- **Interactive menu system** - No command-line arguments needed for beginners
- **Automatic tool detection** - Warns about missing dependencies
- **Format auto-detection** - Recognizes archive types from file extensions
- **Human-readable sizes** - Shows KB, MB, GB instead of bytes
- **Compression statistics** - Displays original vs compressed size with ratios
- **Time tracking** - Shows how long operations take
- **Safe defaults** - Asks before dangerous operations (delete, overwrite)

## 📋 Requirements

### System Requirements
- **Bash 4.0 or higher**
- **bc** - For size calculations (optional but recommended)
- **pv** - For progress bars (optional but recommended)

### Format-Specific Tools
| Format | Required Tools |
|--------|---------------|
| tar | `tar` |
| tar.gz | `tar`, `gzip` |
| tar.bz2 | `tar`, `bzip2` |
| tar.xz | `tar`, `xz` |
| tar.zst | `tar`, `zstd` |
| zip | `zip`, `unzip` |
| 7z | `p7zip` or `7z` |

### Quick Install Dependencies

**Debian/Ubuntu:**
```
sudo apt install tar gzip bzip2 xz-utils zstd zip unzip p7zip-full pv bc
```

**RHEL/CentOS/Fedora:**
```
sudo yum install tar gzip bzip2 xz zstd zip unzip p7zip p7zip-plugins pv bc
```

**Arch Linux:**
```
sudo pacman -S tar gzip bzip2 xz zstd zip unzip p7zip pv bc
```

**macOS (Homebrew):**
```
brew install pv bc p7zip
```

## 🚀 Installation

### Method 1: Quick Install (Recommended)

```
# Download and install
git clone https://github.com/mrAibo/pac-universal-packer.git
cd pac-universal-packer
chmod +x pac.sh

# System-wide installation
sudo cp pac.sh /usr/local/bin/pac

# Enable bash completion
sudo cp pac-completion.sh /etc/bash_completion.d/pac
source ~/.bashrc
```

### Method 2: Function in .bashrc

```
# Add to your .bashrc
echo "source $(pwd)/pac.sh" >> ~/.bashrc
source ~/.bashrc
```

### Method 3: Portable Usage

```
# Just make it executable and run
chmod +x pac.sh
./pac.sh --help
```

## 🎯 Quick Start

### Interactive Mode (Easiest)

Simply run `pac` without arguments to start the interactive menu:

```
pac
```

This will guide you through:
1. Choosing compress/extract/list
2. Selecting format
3. Specifying files
4. Setting options

Perfect for beginners or occasional users!

### Command-Line Examples

#### 💾 Compression

```
# Simple compression with progress bar
pac -c tar.gz -v large_directory/

# Multiple files with custom name
pac -c zip -n my-backup src/ config/ docs/

# With exclusions (exclude node_modules, logs, temp files)
pac -c tar.gz -e "node_modules/" -e "*.log" -e "tmp/" src/

# Password-protected archive
pac -c zip -p project/ confidential_data/

# Dry-run (test without executing)
pac -c tar.gz --dry-run large_directory/

# Silent mode for scripts
pac -c zip -q -n backup src/
```

#### 📦 Extraction

```
# Simple extraction (auto-detects format)
pac archive.zip

# Extract to specific directory with progress
pac -v -t /backup/restored/ archive.tar.gz

# Extract multiple archives
pac *.zip *.tar.gz

# Extract and delete archive after
pac -d old-backup.tar.gz
```

#### 📄 Listing

```
# View archive contents
pac -l archive.zip

# List multiple archives
pac -l *.tar.gz
```

## 📚 Complete Syntax

```
pac [OPTIONS] file1 [file2 ...]
```

### Options Reference

| Short | Long | Description | Example |
|-------|------|-------------|---------|
| `-c FORMAT` | `--compress FORMAT` | Compression mode | `pac -c tar.gz files/` |
| `-x` | `--extract` | Extraction mode (default) | `pac -x archive.zip` |
| `-l` | `--list` | Display archive contents | `pac -l archive.tar.gz` |
| `-v` | `--verbose` | Show progress bar and details | `pac -v -c zip src/` |
| `-q` | `--quiet` | Suppress output (for scripts) | `pac -q -c tar files/` |
| `-t DIR` | `--target DIR` | Specify target directory | `pac -t /backup/ -c zip src/` |
| `-d` | `--delete` | Delete originals after operation | `pac -d archive.zip` |
| `-e PATTERN` | `--exclude PATTERN` | Exclude matching files/dirs | `pac -c zip -e "*.tmp" src/` |
| `-i PATTERN` | `--include PATTERN` | Include only matching files | `pac -c zip -i "*.txt" docs/` |
| `-f FILE` | `--filter FILE` | Read patterns from file | `pac -c zip -f patterns.txt src/` |
| `-n NAME` | `--name NAME` | Custom archive name | `pac -c tar.gz -n backup src/` |
| `-j NUM` | `--jobs NUM` | Parallel compression threads | `pac -c tar.xz -j 8 src/` |
| `-p` | `--password` | Password protection (secure input) | `pac -c zip -p confidential/` |
| | `--dry-run` | Preview without executing | `pac --dry-run -c zip -d src/` |
| | `--no-confirm` | Skip confirmations | `pac -d --no-confirm archive.zip` |
| | `--debug` | Enable debug output | `pac --debug -c zip src/` |
| `-h` | `--help` | Show help message | `pac -h` |

### Shortcut Commands

```
pac c tar.gz files/    # Compress (shortcut)
pac x archive.zip      # Extract (shortcut)
pac l archive.tar.gz   # List (shortcut)
```

## 🎨 Supported Formats

| Format | Extension(s) | Compression | Speed | Ratio | Notes |
|--------|-------------|-------------|-------|-------|-------|
| **tar** | .tar | None | ⚡⚡⚡⚡⚡ | - | Container only |
| **tar.gz** | .tar.gz, .tgz | gzip | ⚡⚡⚡⚡ | 📦📦📦 | Good balance |
| **tar.bz2** | .tar.bz2, .tbz2 | bzip2 | ⚡⚡⚡ | 📦📦📦📦 | Better compression |
| **tar.xz** | .tar.xz, .txz | xz/LZMA | ⚡⚡ | 📦📦📦📦📦 | Best compression |
| **tar.zst** | .tar.zst | zstd | ⚡⚡⚡⚡⚡ | 📦📦📦📦 | Best speed/ratio |
| **zip** | .zip | deflate | ⚡⚡⚡ | 📦📦📦 | Cross-platform |
| **7z** | .7z | LZMA2 | ⚡⚡ | 📦📦📦📦📦 | Maximum compression |

**Legend:** ⚡ = Speed, 📦 = Compression ratio

## 🎓 Advanced Usage

### Pattern-Based Filtering

#### Direct Patterns

```
# Exclude temporary files and logs
pac -c tar.gz -e "*.tmp" -e "*.log" -e "temp/" src/

# Include only documentation
pac -c zip -i "*.md" -i "*.txt" -i "*.pdf" docs/

# Complex exclusions
pac -c tar.gz \
  -e "node_modules/" \
  -e ".git/" \
  -e "*.lock" \
  -e "build/" \
  -e "dist/" \
  project/
```

#### Pattern Files

Create a `patterns.txt` file:

```
# Project backup patterns
# Include source files
+*.js
+*.ts
+*.jsx
+*.tsx
+*.json
+*.md

# Exclude build artifacts
-node_modules/
-build/
-dist/
-*.log
-*.tmp
-.cache/
-.next/

# Exclude version control
-.git/
-.svn/
```

Use it:

```
pac -c tar.gz -f patterns.txt -n project-backup project/
```

### Multithreading & Performance

```
# Auto-detect CPU cores (default)
pac -c tar.xz large_directory/

# Use specific number of threads
pac -c tar.xz -j 8 large_directory/

# Maximum compression with all cores
pac -c tar.xz -j $(nproc) huge_files/

# Fast compression (fewer threads)
pac -c tar.zst -j 2 files/
```

**Performance Tips:**
- **tar.zst**: Fastest with good compression
- **tar.gz**: Good balance, widely supported
- **tar.xz**: Best compression, slower
- **7z**: Maximum compression, very slow

### Password Protection

```
# Interactive password entry (secure - not visible in history)
pac -c zip -p confidential_files/

# For 7z with encryption
pac -c 7z -p sensitive_data/

# Extract password-protected archives
pac encrypted.zip    # Will prompt for password
```

### Dry-Run Mode

Test commands without executing:

```
# Preview what would happen
pac --dry-run -c tar.gz -d -e "*.log" src/

# Output example:
# [DRY-RUN MODE]
# Following operations would be executed:
# Format: tar.gz
#   Output: /backup/src.tar.gz
#   Files: src/
#   Exclude: *.log
```

### Progress Bars

```
# Automatic progress with -v flag
pac -v -c tar.gz large_directory/

# Output shows:
# ℹ Creating src.tar.gz (4.82 GB)
# 4.82GB 0:02:15 [36.2MB/s] [================>  ] 78%
```

## 📊 Real-World Use Cases

### 1. Daily Website Backup

```
#!/bin/bash
# Daily backup script
DATE=$(date +%Y-%m-%d)
pac -c tar.gz \
  -n "website-backup-$DATE" \
  -t /backups/ \
  -e "cache/" \
  -e "*.log" \
  -q \
  /var/www/html/
```

### 2. Project Source Code Archive

```
# Clean project backup excluding dependencies
pac -c tar.gz \
  -n "project-v1.0.0" \
  -e "node_modules/" \
  -e ".git/" \
  -e "dist/" \
  -e "build/" \
  -e "*.log" \
  -v \
  my-project/
```

### 3. Multi-Directory Backup

```
# Backup multiple directories with one command
pac -c tar.gz \
  -n "full-backup-$(date +%Y%m%d)" \
  -t /backup/archives/ \
  -v \
  ~/Documents/ \
  ~/Pictures/ \
  ~/Projects/
```

### 4. Encrypted Document Archive

```
# Secure archive with password
pac -c 7z \
  -p \
  -n "confidential-docs" \
  -i "*.pdf" \
  -i "*.docx" \
  ~/Documents/
```

### 5. Extract and Cleanup

```
# Extract archive and remove it
pac -d -v archive.tar.gz

# Or with confirmation
pac -d archive.tar.gz    # Asks before deleting
```

### 6. Server Log Rotation

```
#!/bin/bash
# Compress and archive old logs
find /var/log -name "*.log" -mtime +7 -type f | while read log; do
  pac -c tar.gz -d -q "$log"
done
```

## 🎯 Example Output

### Compression with Statistics

```
$ pac -v -c tar.gz large_project/

ℹ Checking dependencies...
ℹ Creating large_project.tar.gz (2.45 GB)
2.45GB 0:01:23 [30.2MB/s] [==================>] 100%
✓ Archive created: large_project.tar.gz
  Size: 892.34 MB (36.4% of original)
  Time: 83s
```

### Extraction

```
$ pac -v backup.tar.gz

ℹ Extracting backup.tar.gz → .
[Extracting files...]
✓ Extracted: backup.tar.gz
```

### Dry-Run

```
$ pac --dry-run -c zip -d -e "*.log" src/

[DRY-RUN MODE]
Following operations would be executed:

  Format: zip
  Output: src.zip
  Files: src/
  Exclude: *.log
  Delete originals: yes
```

## 💡 Tips & Best Practices

### Choosing the Right Format

**For maximum compatibility:** Use `zip`
```
pac -c zip files/
```

**For best compression:** Use `tar.xz` or `7z`
```
pac -c tar.xz -j $(nproc) files/
```

**For best speed:** Use `tar.zst` or `tar.gz`
```
pac -c tar.zst files/
```

**For password protection:** Use `zip` or `7z`
```
pac -c 7z -p confidential/
```

### Performance Optimization

1. **Use multithreading** for large archives:
   ```
   pac -c tar.xz -j $(nproc) large_dir/
   ```

2. **Use tar.zst** for fastest compression with good ratio:
   ```
   pac -c tar.zst files/
   ```

3. **Exclude unnecessary files** early:
   ```
   pac -c tar.gz -e ".git/" -e "node_modules/" project/
   ```

4. **Use quiet mode** in scripts to reduce overhead:
   ```
   pac -q -c tar.gz files/
   ```

### Safety Tips

1. **Always test with --dry-run** first:
   ```
   pac --dry-run -c tar.gz -d large_directory/
   ```

2. **Use confirmation prompts** for delete operations (default behavior)

3. **Verify archives** before deleting originals:
   ```
   pac -c tar.gz files/
   pac -l files.tar.gz    # Verify contents
   rm -rf files/          # Delete only after verification
   ```

4. **Keep originals** until backup is verified:
   ```
   # DON'T: pac -c tar.gz -d important_files/
   # DO:
   pac -c tar.gz important_files/
   # Verify, then manually delete
   ```

## 🐛 Troubleshooting

### Common Issues

#### "Command not found" Error

**Problem:** Missing tool
```
$ pac -c tar.xz files/
✗ ERROR: xz is not installed
```

**Solution:**
```
# Ubuntu/Debian
sudo apt install xz-utils

# RHEL/CentOS
sudo yum install xz
```

#### No Progress Bar

**Problem:** `pv` not installed
```
⚠ WARNING: pv not installed - no progress display available
```

**Solution:**
```
sudo apt install pv    # Debian/Ubuntu
sudo yum install pv    # RHEL/CentOS
brew install pv        # macOS
```

#### Archive Corruption

**Problem:** "Archive corrupted or incomplete"

**Solution:**
1. Check disk space: `df -h`
2. Verify file integrity: `pac -l archive.tar.gz`
3. Try extracting with original tool: `tar -tzf archive.tar.gz`
4. Check for write permissions

#### Pattern Not Working

**Problem:** Files still included despite exclusion

**Solution:**
```
# Use --debug to see what's happening
pac --debug -c zip -e "*.log" src/

# Try absolute patterns
pac -c zip -e "src/*.log" src/

# Or use pattern file
echo "-*.log" > patterns.txt
pac -c zip -f patterns.txt src/
```

### Debug Mode

Enable detailed output:

```
pac --debug -c tar.gz files/

# Output:
# DEBUG: Mode: compress
# DEBUG: Target directory: .
# DEBUG: Output file: files.tar.gz
# DEBUG: Input files: files/
# DEBUG: Space check: OK
# ...
```

### Performance Issues

**Slow compression:**
```
# Increase threads
pac -c tar.xz -j $(nproc) files/

# Or use faster format
pac -c tar.zst files/
```

**Out of disk space:**
```
# PAC automatically checks space before operation
✗ ERROR: Not enough disk space available
✗ ERROR: Required: ~2.45 GB, Available: 1.82 GB
```

## 📖 FAQ

**Q: Can PAC handle very large files (100GB+)?**  
A: Yes, PAC streams data and shows progress. Use `-v` for progress tracking.

**Q: Is PAC safe for production use?**  
A: Yes, PAC includes safety features like dry-run, confirmations, and space checks.

**Q: Can I use PAC in automated scripts?**  
A: Yes, use `-q` (quiet) and `--no-confirm` flags for non-interactive use.

**Q: Does PAC preserve file permissions?**  
A: Yes, tar-based formats preserve permissions by default.

**Q: Can I compress to a remote location?**  
A: Yes, specify remote path with `-t`: `pac -c tar.gz -t /mnt/nfs/backup/ files/`

**Q: How do I report bugs?**  
A: Create an issue on GitHub with `--debug` output and steps to reproduce.

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### How to Contribute

1. **Fork the repository**
   ```
   git fork https://github.com/mrAibo/pac-universal-packer.git
   ```

2. **Create a feature branch**
   ```
   git checkout -b feature/my-new-feature
   ```

3. **Make your changes** following the coding style

4. **Test thoroughly**
   ```
   # Test compression
   ./pac.sh -c tar.gz test_files/
   
   # Test extraction
   ./pac.sh test_files.tar.gz
   
   # Test dry-run
   ./pac.sh --dry-run -c zip test_files/
   ```

5. **Run shellcheck** (if available)
   ```
   shellcheck pac.sh
   ```

6. **Commit with clear messages**
   ```
   git commit -m "Add: Support for rar format"
   ```

7. **Create a pull request** with detailed description

### Coding Guidelines

- Follow existing code style
- Add comments for complex logic
- Use `log_debug` for debugging output
- Handle errors gracefully
- Update README for new features

## 📝 License

This project is licensed under the **GNU GPL v3 License**.

See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with best practices from the Bash community
- Inspired by the need for a unified archive tool
- Thanks to all contributors and users

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/mrAibo/pac-universal-packer/issues)
- **Documentation:** [Wiki](https://github.com/mrAibo/pac-universal-packer/wiki)
- **Discussions:** [GitHub Discussions](https://github.com/mrAibo/pac-universal-packer/discussions)

## 🗺️ Roadmap

- [ ] Add RAR support
- [ ] Implement incremental backups
- [ ] Add config file support
- [ ] Cloud storage integration (S3, GCS)
- [ ] GUI wrapper (optional)
- [ ] Windows WSL support improvements

---

**Made with ❤️ for the Linux community**

**Star ⭐ this repo if you find it useful!**
```
