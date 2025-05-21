#!/bin/bash
# Helper script to download shunit2

# Exit on error
set -e

# Default shunit2 version - can be overridden by an environment variable
DEFAULT_SHUNIT2_VERSION="2.1.8"
SHUNIT2_VERSION="${SHUNIT2_VERSION:-$DEFAULT_SHUNIT2_VERSION}"

# Directory to download shunit2 into
SHUNIT2_PARENT_DIR="$(dirname "$0")" # Place shunit2 within the tests directory
SHUNIT2_DIR="${SHUNIT2_PARENT_DIR}/shunit2"
SHUNIT2_DOWNLOAD_URL="https://github.com/kward/shunit2/archive/v${SHUNIT2_VERSION}.tar.gz"
SHUNIT2_ARCHIVE_NAME="shunit2.tar.gz"

# Check if shunit2 directory already exists
if [ -d "$SHUNIT2_DIR" ] && [ -f "$SHUNIT2_DIR/shunit2" ]; then
    echo "shunit2 already present in $SHUNIT2_DIR. Skipping download."
    exit 0
fi

echo "Downloading shunit2 version ${SHUNIT2_VERSION}..."

# Cleanup any partial download
rm -rf "$SHUNIT2_DIR" "$SHUNIT2_ARCHIVE_NAME"
mkdir -p "$SHUNIT2_DIR"

# Download shunit2
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$SHUNIT2_DOWNLOAD_URL" -o "$SHUNIT2_ARCHIVE_NAME"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$SHUNIT2_ARCHIVE_NAME" "$SHUNIT2_DOWNLOAD_URL"
else
    echo "Error: curl or wget is required to download shunit2." >&2
    rm -rf "$SHUNIT2_DIR" "$SHUNIT2_ARCHIVE_NAME" # Clean up
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to download shunit2 from $SHUNIT2_DOWNLOAD_URL" >&2
    rm -rf "$SHUNIT2_DIR" "$SHUNIT2_ARCHIVE_NAME" # Clean up
    exit 1
fi

# Extract shunit2
# The tarball from GitHub has a top-level directory like 'shunit2-2.1.8/'
# We use --strip-components=1 to get rid of it and place contents directly in $SHUNIT2_DIR
echo "Extracting shunit2..."
tar -xzf "$SHUNIT2_ARCHIVE_NAME" -C "$SHUNIT2_DIR" --strip-components=1
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract shunit2 archive." >&2
    rm -rf "$SHUNIT2_DIR" "$SHUNIT2_ARCHIVE_NAME" # Clean up
    exit 1
fi

# Verify shunit2 executable exists
if [ ! -f "$SHUNIT2_DIR/shunit2" ]; then
    echo "Error: shunit2 executable not found after extraction." >&2
    # Attempt to find it if structure was unexpected (e.g. shunit2-shunit2)
    if [ -f "$SHUNIT2_DIR/shunit2/shunit2" ]; then
        echo "Found shunit2 in a subdirectory, attempting to move..."
        mv "$SHUNIT2_DIR"/shunit2/* "$SHUNIT2_DIR/"
        rm -r "$SHUNIT2_DIR"/shunit2
         if [ ! -f "$SHUNIT2_DIR/shunit2" ]; then
             echo "Still could not locate shunit2 executable. Please check the archive structure." >&2
             rm -rf "$SHUNIT2_DIR" "$SHUNIT2_ARCHIVE_NAME"
             exit 1
         fi
    else
        rm -rf "$SHUNIT2_DIR" "$SHUNIT2_ARCHIVE_NAME"
        exit 1
    fi
fi

# Clean up downloaded archive
rm "$SHUNIT2_ARCHIVE_NAME"

echo "shunit2 successfully downloaded and installed to $SHUNIT2_DIR"
exit 0
