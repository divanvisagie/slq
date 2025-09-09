#!/bin/bash
# Development helper script for slq CLI
# Provides common development tasks and shortcuts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory
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
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Helper functions
show_help() {
    echo "slq Development Helper Script"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  setup       - Set up development environment"
    echo "  build       - Build debug version"
    echo "  release     - Build release version"
    echo "  test        - Run all tests"
    echo "  quick-test  - Run quick tests only"
    echo "  watch       - Watch for changes and rebuild"
    echo "  clean       - Clean build artifacts"
    echo "  lint        - Run linting and formatting"
    echo "  install     - Install locally for development"
    echo "  install-sys - Install system-wide (requires sudo)"
    echo "  demo        - Run a demo of slq functionality"
    echo "  deps        - Check and update dependencies"
    echo "  size        - Show binary size information"
    echo "  help        - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 setup           # First-time setup"
    echo "  $0 build           # Quick build"
    echo "  $0 test            # Run all tests"
    echo "  $0 demo            # See slq in action"
}

setup_dev_environment() {
    log_info "Setting up development environment..."

    cd "$PROJECT_DIR"

    # Check if Rust is installed
    if ! command -v cargo >/dev/null 2>&1; then
        log_error "Cargo not found. Please install Rust: https://rustup.rs/"
        exit 1
    fi

    # Check if direnv is available and .envrc exists
    if command -v direnv >/dev/null 2>&1; then
        if [[ -f ".envrc" ]]; then
            log_info "Found .envrc file. Make sure to run 'direnv allow' in this directory."
        else
            log_warning ".envrc file not found. You may need to manually add ./bin to your PATH."
        fi
    else
        log_warning "direnv not found. Consider installing it for automatic PATH management."
    fi

    # Create bin directory if it doesn't exist
    mkdir -p bin

    # Install development tools (optional)
    if command -v cargo-watch >/dev/null 2>&1; then
        log_info "cargo-watch is already installed"
    else
        log_info "Consider installing cargo-watch for file watching: cargo install cargo-watch"
    fi

    log_success "Development environment setup complete!"
}

build_debug() {
    log_info "Building debug version..."
    cd "$PROJECT_DIR"
    cargo build
    log_success "Debug build complete!"
}

build_release() {
    log_info "Building release version..."
    cd "$PROJECT_DIR"
    cargo build --release
    log_success "Release build complete!"
}

run_tests() {
    log_info "Running all tests..."
    cd "$PROJECT_DIR"

    # Unit tests
    log_info "Running unit tests..."
    cargo test

    # Integration tests (if available)
    if [[ -f "scripts/test-integration.sh" ]]; then
        log_info "Running integration tests..."
        make test-integration || true
    fi

    # Black box tests (if available)
    if [[ -f "scripts/test-blackbox.sh" ]]; then
        log_info "Running black box tests..."
        make test-blackbox || true
    fi

    log_success "All tests completed!"
}

run_quick_tests() {
    log_info "Running quick tests only..."
    cd "$PROJECT_DIR"
    cargo test
    log_success "Quick tests completed!"
}

watch_files() {
    log_info "Watching for file changes..."
    cd "$PROJECT_DIR"

    if command -v cargo-watch >/dev/null 2>&1; then
        cargo watch -x "build"
    else
        log_error "cargo-watch not installed. Install with: cargo install cargo-watch"
        exit 1
    fi
}

clean_build() {
    log_info "Cleaning build artifacts..."
    cd "$PROJECT_DIR"
    cargo clean
    rm -rf bin/slq
    log_success "Clean complete!"
}

run_lint() {
    log_info "Running linting and formatting..."
    cd "$PROJECT_DIR"

    # Format code
    log_info "Formatting code..."
    cargo fmt

    # Run clippy
    log_info "Running clippy..."
    cargo clippy -- -D warnings

    log_success "Linting complete!"
}

install_locally() {
    log_info "Installing locally for development..."
    cd "$PROJECT_DIR"

    # Build release version
    cargo build --release

    # Copy to local bin
    mkdir -p bin
    cp target/release/slq bin/slq

    log_success "Installed to ./bin/slq"
    log_info "Make sure ./bin is in your PATH or use the .envrc file"
}

install_system() {
    log_info "Installing system-wide..."
    cd "$PROJECT_DIR"

    # The installer auto-detects permissions and falls back to user directory
    cargo run --bin install
}

run_demo() {
    log_info "Running slq demo..."
    cd "$PROJECT_DIR"

    # Ensure we have a binary
    if [[ ! -f "bin/slq" && ! -f "target/release/slq" ]]; then
        log_info "No binary found, building release version..."
        cargo build --release
    fi

    # Set binary path
    local slq_bin
    if [[ -f "bin/slq" ]]; then
        slq_bin="./bin/slq"
    else
        slq_bin="./target/release/slq"
    fi

    echo
    log_info "=== SLQ Demo ==="
    echo

    echo "1. Searching for stations containing 'Central':"
    echo "   Command: $slq_bin search \"Central\""
    echo
    "$slq_bin" search "Central" | head -5
    echo "   (showing first 5 results)"
    echo

    echo "2. Getting departures from T-Centralen:"
    echo "   Command: $slq_bin departures \"T-Centralen\""
    echo
    "$slq_bin" departures "T-Centralen" | head -8
    echo "   (showing first few departures)"
    echo

    echo "3. Planning a journey:"
    echo "   Command: $slq_bin journey \"T-Centralen\" \"Slussen\""
    echo
    "$slq_bin" journey "T-Centralen" "Slussen"
    echo

    echo "4. Shell scripting example - Get station ID:"
    echo "   Command: $slq_bin search \"T-Centralen\" | head -1 | cut -f2"
    echo
    local station_id
    station_id=$("$slq_bin" search "T-Centralen" | head -1 | cut -f2)
    echo "   Result: $station_id"
    echo

    log_success "Demo complete! Try these commands yourself."
}

check_dependencies() {
    log_info "Checking dependencies..."
    cd "$PROJECT_DIR"

    # Show current dependencies
    echo "Current dependencies:"
    grep "^\[dependencies\]" -A 20 Cargo.toml | grep -v "^\[" | head -10

    echo
    echo "Checking for updates..."
    if command -v cargo-outdated >/dev/null 2>&1; then
        cargo outdated
    else
        log_info "Install cargo-outdated for dependency update checking: cargo install cargo-outdated"
    fi

    # Check for security advisories
    if command -v cargo-audit >/dev/null 2>&1; then
        echo
        echo "Security audit:"
        cargo audit
    else
        log_info "Install cargo-audit for security checking: cargo install cargo-audit"
    fi
}

show_binary_size() {
    log_info "Binary size information..."
    cd "$PROJECT_DIR"

    local debug_bin="target/debug/slq"
    local release_bin="target/release/slq"

    if [[ -f "$debug_bin" ]]; then
        local debug_size
        debug_size=$(stat -f%z "$debug_bin" 2>/dev/null || stat -c%s "$debug_bin" 2>/dev/null)
        echo "Debug binary: $debug_size bytes"
    else
        echo "Debug binary: not built"
    fi

    if [[ -f "$release_bin" ]]; then
        local release_size
        release_size=$(stat -f%z "$release_bin" 2>/dev/null || stat -c%s "$release_bin" 2>/dev/null)
        echo "Release binary: $release_size bytes"

        # Show what's taking space
        if command -v bloaty >/dev/null 2>&1; then
            echo
            echo "Binary analysis (top sections):"
            bloaty "$release_bin" -n 10
        fi
    else
        echo "Release binary: not built"
    fi
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        setup)
            setup_dev_environment
            ;;
        build)
            build_debug
            ;;
        release)
            build_release
            ;;
        test)
            run_tests
            ;;
        quick-test)
            run_quick_tests
            ;;
        watch)
            watch_files
            ;;
        clean)
            clean_build
            ;;
        lint)
            run_lint
            ;;
        install)
            install_locally
            ;;
        install-sys)
            install_system
            ;;
        demo)
            run_demo
            ;;
        deps)
            check_dependencies
            ;;
        size)
            show_binary_size
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
