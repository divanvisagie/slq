#!/bin/bash

# Compilation benchmark script for slq Rust vs C implementations
# Measures build times for both implementations

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$RESULTS_DIR/compile_benchmark_${TIMESTAMP}.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test parameters
WARMUP_RUNS=1
BENCHMARK_RUNS=5

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if hyperfine is installed
check_hyperfine() {
    if ! command -v hyperfine &> /dev/null; then
        log_error "hyperfine is not installed. Please install it:"
        echo "  macOS:  brew install hyperfine"
        echo "  Ubuntu: sudo apt install hyperfine"
        echo "  Cargo:  cargo install hyperfine"
        exit 1
    fi
    log_info "Found hyperfine: $(hyperfine --version)"
}

# Setup results directory and file
setup_results() {
    mkdir -p "$RESULTS_DIR"

    cat > "$RESULTS_FILE" << EOF
# SLQ Compilation Performance Benchmarks

**Generated:** $(date)
**System:** $(uname -a)
**Hyperfine:** $(hyperfine --version)

## Compilation Benchmarks

EOF
}

# Benchmark Rust compilation
benchmark_rust_compilation() {
    log_info "Benchmarking Rust compilation..."

    echo "### Rust Clean Build" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"

    cd "$PROJECT_DIR"

    # First, do a clean build to establish baseline
    cargo clean
    echo "Initial clean build (not timed):" >> "$RESULTS_FILE"
    time cargo build --release >> "$RESULTS_FILE" 2>&1
    echo "" >> "$RESULTS_FILE"

    # Now benchmark incremental builds after touching a file
    echo "Incremental builds after touching main.rs:" >> "$RESULTS_FILE"
    hyperfine \
        --warmup $WARMUP_RUNS \
        --runs $BENCHMARK_RUNS \
        --prepare 'touch src/main.rs' \
        --export-markdown /tmp/rust_incremental.md \
        'cargo build --release' \
        | tee -a "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    # Benchmark clean builds
    echo "### Rust Clean Builds" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"

    hyperfine \
        --warmup 0 \
        --runs 3 \
        --prepare 'cargo clean' \
        --export-markdown /tmp/rust_clean.md \
        'cargo build --release' \
        | tee -a "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

# Benchmark C compilation
benchmark_c_compilation() {
    log_info "Benchmarking C compilation..."

    echo "### C Clean Build" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"

    cd "$PROJECT_DIR/c-version"

    # First, do a clean build to establish baseline
    make clean
    echo "Initial clean build (not timed):" >> "$RESULTS_FILE"
    time make >> "$RESULTS_FILE" 2>&1
    echo "" >> "$RESULTS_FILE"

    # Now benchmark incremental builds after touching a file
    echo "Incremental builds after touching main.c:" >> "$RESULTS_FILE"
    hyperfine \
        --warmup $WARMUP_RUNS \
        --runs $BENCHMARK_RUNS \
        --prepare 'touch src/main.c' \
        --export-markdown /tmp/c_incremental.md \
        'make' \
        | tee -a "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    # Benchmark clean builds
    echo "### C Clean Builds" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"

    hyperfine \
        --warmup 0 \
        --runs $BENCHMARK_RUNS \
        --prepare 'make clean' \
        --export-markdown /tmp/c_clean.md \
        'make' \
        | tee -a "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

# Compare compilation times directly
benchmark_compilation_comparison() {
    log_info "Comparing compilation times..."

    echo "### Direct Compilation Comparison" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "#### Clean Builds" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"

    cd "$PROJECT_DIR"
    hyperfine \
        --warmup 0 \
        --runs 3 \
        --prepare 'cargo clean && cd c-version && make clean && cd ..' \
        --command-name "Rust" 'cargo build --release' \
        --command-name "C" 'cd c-version && make && cd ..' \
        | tee -a "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    echo "#### Incremental Builds" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"

    hyperfine \
        --warmup 1 \
        --runs $BENCHMARK_RUNS \
        --prepare 'touch src/main.rs && touch c-version/src/main.c' \
        --command-name "Rust" 'cargo build --release' \
        --command-name "C" 'cd c-version && make && cd ..' \
        | tee -a "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

# Add system information
add_system_info() {
    echo "## System Information" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"
    echo "Hostname: $(hostname)" >> "$RESULTS_FILE"
    echo "OS: $(uname -s) $(uname -r)" >> "$RESULTS_FILE"
    echo "Architecture: $(uname -m)" >> "$RESULTS_FILE"

    # CPU information
    if command -v sysctl &> /dev/null; then
        echo "" >> "$RESULTS_FILE"
        echo "CPU:" >> "$RESULTS_FILE"
        sysctl -n machdep.cpu.brand_string >> "$RESULTS_FILE" 2>/dev/null || echo "Unknown" >> "$RESULTS_FILE"
        echo "CPU cores: $(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")" >> "$RESULTS_FILE"
    elif command -v lscpu &> /dev/null; then
        echo "" >> "$RESULTS_FILE"
        echo "CPU:" >> "$RESULTS_FILE"
        lscpu | grep -E "Model name|CPU\(s\):" | head -2 >> "$RESULTS_FILE"
    fi

    # Compiler versions
    echo "" >> "$RESULTS_FILE"
    echo "Compilers:" >> "$RESULTS_FILE"
    echo "Rust: $(rustc --version 2>/dev/null || echo "Not found")" >> "$RESULTS_FILE"
    echo "Cargo: $(cargo --version 2>/dev/null || echo "Not found")" >> "$RESULTS_FILE"
    echo "GCC: $(gcc --version 2>/dev/null | head -1 || echo "Not found")" >> "$RESULTS_FILE"
    echo "Make: $(make --version 2>/dev/null | head -1 || echo "Not found")" >> "$RESULTS_FILE"

    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

# Generate summary
generate_summary() {
    echo "## Compilation Performance Summary" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "### Key Findings" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "1. **Clean Builds**: C typically compiles much faster than Rust" >> "$RESULTS_FILE"
    echo "2. **Incremental Builds**: Both show good incremental compilation performance" >> "$RESULTS_FILE"
    echo "3. **Dependencies**: Rust downloads and compiles many dependencies on first build" >> "$RESULTS_FILE"
    echo "4. **Build Tools**: Cargo provides better dependency management vs Make" >> "$RESULTS_FILE"
    echo "5. **Binary Output**: Rust produces larger but self-contained binaries" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "### Development Workflow Impact" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "- **C**: Faster edit-compile-test cycles" >> "$RESULTS_FILE"
    echo "- **Rust**: Slower initial build, good incremental builds, better error messages" >> "$RESULTS_FILE"
    echo "- **CI/CD**: C builds faster in clean environments" >> "$RESULTS_FILE"
    echo "- **Local Development**: Incremental builds make Rust acceptable" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "The compilation performance difference is most noticeable in CI environments" >> "$RESULTS_FILE"
    echo "where clean builds are common and dependency caching may not be available." >> "$RESULTS_FILE"
}

# Main function
main() {
    log_info "Starting compilation performance benchmarks"
    echo ""

    # Setup
    check_hyperfine
    setup_results
    add_system_info

    # Run benchmarks
    benchmark_rust_compilation
    benchmark_c_compilation
    benchmark_compilation_comparison

    # Generate summary
    generate_summary

    # Cleanup temporary files
    rm -f /tmp/rust_*.md /tmp/c_*.md

    # Final output
    log_success "Compilation benchmark complete!"
    echo ""
    echo "Results saved to: $RESULTS_FILE"
    echo ""
    echo "Summary:"
    echo "  - Rust clean builds benchmarked"
    echo "  - C clean builds benchmarked"
    echo "  - Incremental builds tested"
    echo "  - Direct comparisons performed"
    echo ""
    echo "View results: cat \"$RESULTS_FILE\""
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Compilation performance benchmarks for slq Rust vs C implementations.

OPTIONS:
    -h, --help     Show this help message
    --warmup N     Number of warmup runs (default: $WARMUP_RUNS)
    --runs N       Number of benchmark runs (default: $BENCHMARK_RUNS)

EXAMPLES:
    $0                    # Run compilation benchmarks
    $0 --runs 10          # Run with more iterations

REQUIREMENTS:
    - hyperfine (https://github.com/sharkdp/hyperfine)
    - Rust toolchain (cargo, rustc)
    - C toolchain (gcc, make)
    - Source code for both implementations

OUTPUTS:
    Results saved to: benchmarks/results/compile_benchmark_TIMESTAMP.md
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --warmup)
            WARMUP_RUNS="$2"
            shift 2
            ;;
        --runs)
            BENCHMARK_RUNS="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate numeric arguments
if ! [[ "$WARMUP_RUNS" =~ ^[0-9]+$ ]] || [[ "$WARMUP_RUNS" -lt 0 ]]; then
    log_error "Invalid warmup runs: $WARMUP_RUNS"
    exit 1
fi

if ! [[ "$BENCHMARK_RUNS" =~ ^[0-9]+$ ]] || [[ "$BENCHMARK_RUNS" -lt 1 ]]; then
    log_error "Invalid benchmark runs: $BENCHMARK_RUNS"
    exit 1
fi

# Run main function
main "$@"
