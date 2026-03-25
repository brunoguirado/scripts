#!/bin/bash
# ==============================================================================
# Antigravity Fix: nsjail GRTE Loader Symlink
# ==============================================================================
# Problem: nsjail binary is hardcoded to look for the loader in /usr/grte/v5/...
# Solution: Create a symlink from the system's real ld-linux to the expected path.
# ==============================================================================

set -e

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo bash $0)"
    exit 1
fi

echo "🚀 Applying nsjail GRTE loader fix..."

# 2. Create the internal GRTE structure
TARGET_DIR="/usr/grte/v5/lib64"
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 Creating structure: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# 3. Create the symlink
REAL_LOADER="/lib64/ld-linux-x86-64.so.2"
FIX_PATH="$TARGET_DIR/ld-linux-x86-64.so.2"

if [ ! -f "$REAL_LOADER" ]; then
    echo "⚠️  Internal loader $REAL_LOADER not found. Checking alternate paths..."
    REAL_LOADER=$(find /lib /usr/lib -name "ld-linux-x86-64.so.2" | head -1)
fi

if [ -n "$REAL_LOADER" ] && [ -f "$REAL_LOADER" ]; then
    echo "🔗 Linking $REAL_LOADER -> $FIX_PATH"
    ln -sf "$REAL_LOADER" "$FIX_PATH"
    echo "✅ Fix applied successfully."
else
    echo "❌ Could not find ld-linux-x86-64.so.2 on this system."
    exit 1
fi

echo "💡 Test the sandbox again to verify the fix."
