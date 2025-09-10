# SLQ Benchmarks

This directory contains comprehensive benchmarking tools for comparing the Rust and C implementations of slq (Stockholm Local Traffic Query).

## Overview

The benchmarking suite uses [hyperfine](https://github.com/sharkdp/hyperfine) to provide accurate, statistical performance measurements across multiple dimensions:

- **Cold Start Performance**: Binary startup overhead and initialization time
- **Runtime Performance**: Network operations, search, and departures functionality  
- **Memory Usage**: Memory consumption analysis
- **Compilation Performance**: Build time comparisons
- **Workflow Performance**: End-to-end user scenarios

## Quick Start

### Prerequisites

```bash
# Install hyperfine
brew install hyperfine          # macOS
sudo apt install hyperfine      # Ubuntu
cargo install hyperfine         # Any platform with Rust

# Ensure both implementations are built
make build-release              # Rust version
make build-c                    # C version
```

### Running Benchmarks

```bash
# Quick runtime benchmarks (recommended)
make benchmark-quick

# Comprehensive runtime benchmarks
make benchmark-simple

# Full benchmarks including compilation (takes longer)
make benchmark
```

## Benchmark Scripts

### `simple_benchmark.sh` (Recommended)

Focuses on runtime performance without compilation overhead:

```bash
./benchmarks/simple_benchmark.sh [OPTIONS]

Options:
  --warmup N    Number of warmup runs (default: 2)
  --runs N      Number of benchmark runs (default: 8)
```

**Features:**
- Cold start performance (help, error handling)
- Search operations (simple, complex, comprehensive)
- Departures operations (by name, ID, with filtering)
- Workflow testing (search → departures)
- Memory usage analysis
- System information capture

### `benchmark.sh` (Full Suite)

Comprehensive benchmarks including compilation:

```bash
./benchmarks/benchmark.sh [OPTIONS]
```

**Additional Features:**
- Rust compilation benchmarks (`cargo build --release`)
- C compilation benchmarks (`make`)
- Concurrency testing
- More detailed memory analysis

## Results

Benchmark results are automatically saved to `results/` with timestamps:

```
benchmarks/results/
├── simple_benchmark_20240101_120000.md
├── benchmark_20240101_130000.md
└── ...
```

Results include:
- Detailed timing statistics with standard deviations
- Binary size comparisons
- System information
- Performance summaries and recommendations

## Typical Results

Based on testing on Apple M3 (ARM64):

### Binary Sizes
- **Rust**: ~5.1MB (statically linked)
- **C**: ~37KB (dynamically linked)

### Cold Start Performance
- **Rust**: ~3-4ms (help command)
- **C**: ~5-6ms (help command)

*Note: Rust is faster for cold start on this system, contrary to expectations*

### Network Operations
- **Search/Departures**: Very similar performance (~1.3-1.8s)
- **C typically 5-15% faster** for network-bound operations
- Performance is primarily limited by API response time

### Memory Usage
- **C**: Lower memory footprint
- **Rust**: Higher due to runtime and allocator overhead

## Performance Insights

### When C is Faster
- Network operations (slight advantage)
- Memory-constrained environments
- Departures by station ID (direct API calls)

### When Rust is Faster
- Cold start operations (on some systems)
- Complex error handling
- Some workflow scenarios

### Performance Parity
- Most real-world usage scenarios
- Overall user experience is nearly identical

## Interpreting Results

### Statistical Significance
- Results include standard deviations (±)
- Multiple runs ensure reliability
- Warmup runs eliminate cache effects

### System Dependencies
- Network latency affects API operations
- CPU architecture impacts cold start
- Available memory affects performance

### Practical Impact
- Sub-second differences rarely matter for CLI tools
- Binary size more important for deployment
- Memory usage critical for resource-constrained environments

## Customizing Benchmarks

### Adding New Tests

1. Edit `simple_benchmark.sh` or `benchmark.sh`
2. Add new hyperfine commands in appropriate sections
3. Update result formatting and summaries

### Test Parameters

```bash
# Quick test during development
./simple_benchmark.sh --warmup 1 --runs 3

# High precision for final measurements  
./simple_benchmark.sh --warmup 5 --runs 20
```

### Environment Variables

```bash
# Custom binary locations
RUST_BIN=/path/to/rust/slq SIMPLE_BENCHMARK=1 ./simple_benchmark.sh
```

## Continuous Integration

For CI environments:

```bash
# Fast benchmarks suitable for CI
make benchmark-quick

# Check for performance regressions
./benchmarks/simple_benchmark.sh --runs 5 > results/ci_benchmark.md
```

## Troubleshooting

### Common Issues

**hyperfine not found**
```bash
# Install hyperfine first
brew install hyperfine  # macOS
```

**Binaries not found**
```bash
# Build both implementations
make build-release build-c
```

**Network timeouts**
```bash
# Check internet connectivity
curl -s "https://transport.integration.sl.se/v1/sites" | head
```

**Memory analysis unavailable**
```bash
# Install GNU time for detailed memory stats
brew install gnu-time  # macOS
```

### Performance Variations

Network-dependent operations show natural variation due to:
- API server load
- Network latency
- Local system load

This is normal and expected for real-world CLI tools.

## Contributing

When adding benchmarks:

1. Use descriptive test names
2. Include appropriate warmup runs
3. Consider statistical significance
4. Update documentation
5. Test on multiple systems when possible

The goal is to provide actionable performance insights for choosing between implementations based on specific deployment requirements.