#!/bin/bash
# One-command installer for slq
# This script handles everything: dependencies, configuration, build, and installation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Functions for output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${BOLD}$1${NC}"
    echo "$(echo "$1" | sed 's/./=/g')"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

One-command installer for slq - automatically handles dependencies,
configuration, build, and installation.

OPTIONS:
    --user              Install to user directory (~/.local) instead of system-wide
    --prefix=DIR        Custom installation prefix (default: /usr/local)
    --dev               Setup for development (debug + sanitizers)
    --help              Show this help message

EXAMPLES:
    $0                  # Install system-wide to /usr/local
    $0 --user           # Install to ~/.local
    $0 --prefix=/usr    # Install to /usr
    $0 --dev            # Development setup

This script will:
1. Check and install missing dependencies automatically
2. Configure the build environment
3. Build the project
4. Run tests to verify everything works
5. Install slq and its manual page

EOF
}

# Parse arguments
USER_INSTALL=false
DEV_MODE=false
PREFIX=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            USER_INSTALL=true
            shift
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --dev)
            DEV_MODE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main installation process
main() {
    log_header "slq One-Command Installer"
    echo "This will install slq and all its dependencies automatically."
    echo ""

    # Step 1: Configure with auto-install
    log_header "Step 1: Checking Dependencies and Configuration"

    configure_args=""

    if [[ -n "$PREFIX" ]]; then
        configure_args="$configure_args --prefix=$PREFIX"
    fi

    if [[ "$DEV_MODE" == true ]]; then
        configure_args="$configure_args --enable-debug --enable-sanitizers"
        log_info "Development mode enabled"
    fi

    log_info "Running: ./configure $configure_args"
    ./configure $configure_args

    # Step 2: Build
    log_header "Step 2: Building"
    log_info "Compiling slq..."
    make clean
    make

    # Step 3: Test
    log_header "Step 3: Testing"
    log_info "Running tests to verify build..."
    make test-basic

    # Step 4: Install
    log_header "Step 4: Installing"

    if [[ "$USER_INSTALL" == true ]]; then
        log_info "Installing to user directory (~/.local)..."
        make install-user

        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            log_warning "~/.local/bin is not in your PATH"
            echo "Add this to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):"
            echo '  export PATH="$HOME/.local/bin:$PATH"'
            echo ""
        fi

        log_success "slq installed to ~/.local/bin/slq"
        log_info "Manual page installed to ~/.local/share/man/man1/slq.1"

    else
        log_info "Installing system-wide..."
        make install

        log_success "slq installed to $(grep PREFIX config.mk | cut -d= -f2 | tr -d ' ')/bin/slq"
        log_info "Manual page installed to $(grep PREFIX config.mk | cut -d= -f2 | tr -d ' ')/share/man/man1/slq.1"
    fi

    # Step 5: Verify installation
    log_header "Step 5: Verification"

    if command -v slq &> /dev/null; then
        log_success "Installation verified! slq is available in PATH"
        echo ""
        echo "Try it out:"
        echo "  slq search \"Central\""
        echo "  slq departures \"T-Centralen\""
        echo "  man slq"
    else
        log_warning "slq not found in PATH - you may need to restart your shell"
        if [[ "$USER_INSTALL" == true ]]; then
            echo "Make sure ~/.local/bin is in your PATH"
        fi
    fi

    echo ""
    log_success "Installation complete! 🎉"

    if [[ "$DEV_MODE" == true ]]; then
        echo ""
        log_info "Development setup complete. You can now:"
        echo "  make test-all       # Run comprehensive tests"
        echo "  make lint           # Run static analysis"
        echo "  make publish-dry    # Preview releases"
    fi
}

# Check if we're in the right directory
if [[ ! -f "configure" ]] || [[ ! -f "Makefile" ]]; then
    log_error "This script must be run from the slq source directory"
    echo "Make sure you're in the directory containing 'configure' and 'Makefile'"
    exit 1
fi

# Run main installation
main "$@"
