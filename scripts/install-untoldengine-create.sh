#!/bin/bash

# install-untoldengine-create.sh
# Installation script for untoldengine-create CLI tool

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CLI_NAME="untoldengine"
INSTALL_DIR="/usr/local/bin"
SUPPORT_DIR="/usr/local/libexec/untoldengine"
BUILD_CONFIG="release"

echo -e "${CYAN}🎮 UntoldEngine CLI Installer${NC}"
echo ""

# Navigate to CLI directory
CLI_DIR="Tools/UntoldEngineCLI"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$REPO_ROOT"

if [ ! -d "$CLI_DIR" ]; then
    echo -e "${RED}❌ Error: CLI directory not found at $CLI_DIR${NC}"
    echo "Please run this script from the UntoldEngine root directory"
    exit 1
fi

cd "$CLI_DIR"

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Error: Swift is not installed${NC}"
    echo "Please install Xcode or Swift toolchain"
    exit 1
fi

# Build the CLI tool
echo -e "${CYAN}🔨 Building $CLI_NAME from $CLI_DIR...${NC}"
swift build -c $BUILD_CONFIG --product $CLI_NAME

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"
echo ""

# Check if binary exists
BINARY_PATH=".build/$BUILD_CONFIG/$CLI_NAME"
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}❌ Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# Install the binary
echo -e "${CYAN}📦 Installing to $INSTALL_DIR/$CLI_NAME...${NC}"

# Ensure the install directory exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠️  Creating install directory at $INSTALL_DIR${NC}"
    if [ -w "$(dirname "$INSTALL_DIR")" ]; then
        mkdir -p "$INSTALL_DIR"
    else
        sudo mkdir -p "$INSTALL_DIR"
    fi
fi

# Check if we need sudo
if [ -w "$INSTALL_DIR" ]; then
    cp "$BINARY_PATH" "$INSTALL_DIR/$CLI_NAME"
else
    echo -e "${YELLOW}⚠️  Requesting admin privileges to install to $INSTALL_DIR${NC}"
    sudo cp "$BINARY_PATH" "$INSTALL_DIR/$CLI_NAME"
fi

# Make executable
if [ -w "$INSTALL_DIR/$CLI_NAME" ]; then
    chmod +x "$INSTALL_DIR/$CLI_NAME"
else
    sudo chmod +x "$INSTALL_DIR/$CLI_NAME"
fi

# Install Blender exporter support files used by `untoldengine export`.
echo -e "${CYAN}📦 Installing exporter support files to $SUPPORT_DIR...${NC}"
if [ ! -d "$SUPPORT_DIR" ]; then
    if [ -w "$(dirname "$SUPPORT_DIR")" ]; then
        mkdir -p "$SUPPORT_DIR"
    else
        sudo mkdir -p "$SUPPORT_DIR"
    fi
fi

if [ -w "$SUPPORT_DIR" ]; then
    cp "$REPO_ROOT/scripts/untoldexporter.py" "$SUPPORT_DIR/untoldexporter.py"
    cp "$REPO_ROOT/scripts/untoldexplorer.py" "$SUPPORT_DIR/untoldexplorer.py"
    cp "$REPO_ROOT/scripts/texbake.py" "$SUPPORT_DIR/texbake.py"
else
    sudo cp "$REPO_ROOT/scripts/untoldexporter.py" "$SUPPORT_DIR/untoldexporter.py"
    sudo cp "$REPO_ROOT/scripts/untoldexplorer.py" "$SUPPORT_DIR/untoldexplorer.py"
    sudo cp "$REPO_ROOT/scripts/texbake.py" "$SUPPORT_DIR/texbake.py"
fi

echo -e "${GREEN}✅ Installation complete${NC}"
echo ""

# Verify installation
if command -v $CLI_NAME &> /dev/null; then
    echo -e "${GREEN}✅ Verification successful${NC}"
    echo ""
    echo "You can now run:"
    echo -e "  ${CYAN}$CLI_NAME --help${NC}"
    echo ""
    echo "Examples:"
    echo -e "  ${CYAN}# Create a macOS project${NC}"
    echo -e "  ${CYAN}$CLI_NAME create MyGame${NC}"
    echo ""
    echo -e "  ${CYAN}# Create iOS project${NC}"
    echo -e "  ${CYAN}$CLI_NAME create MyGame --platform ios --team-id YOUR_TEAM_ID${NC}"
    echo ""
    echo -e "  ${CYAN}# Create multi-platform project (macOS, iOS, visionOS)${NC}"
    echo -e "  ${CYAN}$CLI_NAME create MyGame --platform multi --team-id YOUR_TEAM_ID${NC}"
    echo ""
    echo -e "  ${CYAN}# Export USD/USDZ to .untold${NC}"
    echo -e "  ${CYAN}$CLI_NAME export --input model.usdz --output model.untold --convert-orientation${NC}"
    echo ""
    echo -e "  ${CYAN}# Bake textures to .utex${NC}"
    echo -e "  ${CYAN}$CLI_NAME texbake --dir Textures${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠️  Warning: $CLI_NAME not found in PATH${NC}"
    echo "You may need to add $INSTALL_DIR to your PATH"
    echo ""
    echo "Add this line to your ~/.zshrc or ~/.bashrc:"
    echo -e "  ${CYAN}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
    echo ""
fi

echo "Installation completed!"
