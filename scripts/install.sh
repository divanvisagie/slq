#!/bin/bash
# Installation script for slq - Stockholm Local Traffic Query Tool
# Installs slq binary and man page system-wide

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
MAN_DIR="${MAN_DIR:-/usr/local/share/man/man1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root for system installation
check_permissions() {
    if [[ "$INSTALL_DIR" == "/usr"* ]] && [[ $EUID -ne 0 ]]; then
        log_error "System-wide installation requires root privileges"
        log_info "Please run with sudo or specify a user directory:"
        log_info "  sudo $0"
        log_info "  INSTALL_DIR=~/.local/bin $0"
        exit 1
    fi
}

# Show help message
show_help() {
    cat << EOF
slq Installation Script

Usage: $0 [OPTIONS]

Options:
  --help              Show this help message
  --uninstall         Uninstall slq
  --user              Install to user directory (~/.local)
  --prefix PREFIX     Install to custom prefix (default: /usr/local)

Environment Variables:
  INSTALL_DIR         Binary installation directory (default: /usr/local/bin)
  MAN_DIR            Man page directory (default: /usr/local/share/man/man1)

Examples:
  sudo $0                                    # System-wide installation
  $0 --user                                  # User installation
  INSTALL_DIR=~/bin MAN_DIR=~/man $0         # Custom directories
  sudo $0 --prefix /opt/slq                  # Custom prefix

EOF
}

# Set user installation directories
set_user_install() {
    INSTALL_DIR="$HOME/.local/bin"
    MAN_DIR="$HOME/.local/share/man/man1"
    log_info "Installing to user directory: $HOME/.local"
}

# Set custom prefix
set_prefix() {
    local prefix="$1"
    INSTALL_DIR="$prefix/bin"
    MAN_DIR="$prefix/share/man/man1"
    log_info "Installing to prefix: $prefix"
}

# Build the binary
build_binary() {
    log_info "Building slq..."
    cd "$PROJECT_DIR"

    if ! command -v cargo >/dev/null 2>&1; then
        log_error "Cargo not found. Please install Rust: https://rustup.rs/"
        exit 1
    fi

    cargo build --release

    if [[ ! -f "target/release/slq" ]]; then
        log_error "Build failed - binary not found"
        exit 1
    fi

    log_success "Build completed successfully"
}

# Install binary
install_binary() {
    log_info "Installing binary to $INSTALL_DIR"

    # Create directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Copy binary
    cp "$PROJECT_DIR/target/release/slq" "$INSTALL_DIR/slq"
    chmod 755 "$INSTALL_DIR/slq"

    log_success "Binary installed to $INSTALL_DIR/slq"
}

# Install man page
install_man_page() {
    local man_file="$PROJECT_DIR/slq.1"

    if [[ ! -f "$man_file" ]]; then
        log_warning "Man page not found at $man_file, skipping"
        return
    fi

    log_info "Installing man page to $MAN_DIR"

    # Create directory if it doesn't exist
    mkdir -p "$MAN_DIR"

    # Copy man page
    cp "$man_file" "$MAN_DIR/slq.1"
    chmod 644 "$MAN_DIR/slq.1"

    # Update man database if available
    if command -v mandb >/dev/null 2>&1; then
        mandb >/dev/null 2>&1 || log_warning "Failed to update man database"
    fi

    log_success "Man page installed to $MAN_DIR/slq.1"
}

# Uninstall slq
uninstall() {
    log_info "Uninstalling slq..."

    # Remove binary
    if [[ -f "$INSTALL_DIR/slq" ]]; then
        rm -f "$INSTALL_DIR/slq"
        log_success "Removed binary from $INSTALL_DIR/slq"
    else
        log_warning "Binary not found at $INSTALL_DIR/slq"
    fi

    # Remove man page
    if [[ -f "$MAN_DIR/slq.1" ]]; then
        rm -f "$MAN_DIR/slq.1"
        log_success "Removed man page from $MAN_DIR/slq.1"

        # Update man database if available
        if command -v mandb >/dev/null 2>&1; then
            mandb >/dev/null 2>&1 || log_warning "Failed to update man database"
        fi
    else
        log_warning "Man page not found at $MAN_DIR/slq.1"
    fi

    log_success "Uninstallation completed"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    # Check if binary is executable
    if [[ -x "$INSTALL_DIR/slq" ]]; then
        log_success "Binary is executable"
    else
        log_error "Binary is not executable"
        return 1
    fi

    # Check if binary is in PATH
    if command -v slq >/dev/null 2>&1; then
        local version_output
        version_output=$(slq --help | head -1)
        log_success "slq is in PATH: $version_output"
    else
        log_warning "slq is not in PATH. You may need to add $INSTALL_DIR to your PATH"
        log_info "Add this to your shell profile (.bashrc, .zshrc, etc.):"
        log_info "  export PATH=\"$INSTALL_DIR:\$PATH\""
    fi

    # Check man page
    if [[ -f "$MAN_DIR/slq.1" ]]; then
        log_success "Man page installed (try 'man slq')"
    else
        log_warning "Man page not installed"
    fi
}

# Main installation function
main_install() {
    log_info "Installing slq - Stockholm Local Traffic Query Tool"
    log_info "Installation directory: $INSTALL_DIR"
    log_info "Man page directory: $MAN_DIR"
    echo

    check_permissions
    build_binary
    install_binary
    install_man_page
    verify_installation

    echo
    log_success "Installation completed successfully!"
    log_info "Try running: slq search \"Central\""
    log_info "For help: slq --help or man slq"
    log_info "Licensed under BSD 3-Clause License"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --uninstall)
            check_permissions
            uninstall
            exit 0
            ;;
        --user)
            set_user_install
            shift
            ;;
        --prefix)
            if [[ -z "${2:-}" ]]; then
                log_error "--prefix requires an argument"
                exit 1
            fi
            set_prefix "$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main installation
main_install
