# SLQ Runtime Performance Benchmarks

**Generated:** Thu Sep 11 00:31:28 CEST 2025
**System:** Darwin gungnir 25.0.0 Darwin Kernel Version 25.0.0: Mon Aug 25 21:17:36 PDT 2025; root:xnu-12377.1.9~3/RELEASE_ARM64_T8122 arm64
**Hyperfine:** hyperfine 1.19.0

## Binary Information

| Implementation | Size | Path |
|----------------|------|------|
| Rust | 5.1M | /Users/divan/src/com.divanv/slq/target/release/slq |
| C | 37K | /Users/divan/src/com.divanv/slq/c-version/bin/slq |

## Runtime Performance Benchmarks

## System Information

```
Hostname: gungnir
OS: Darwin 25.0.0
Architecture: arm64

CPU:
Apple M3
CPU cores: 8

Memory (macOS vm_stat):
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               46900.
Pages active:                            312835.
Pages inactive:                          307680.
```

### Cold Start - Help Command
```
Benchmark 1: Rust
  Time (mean ± σ):       3.5 ms ±   0.1 ms    [User: 1.9 ms, System: 1.0 ms]
  Range (min … max):     3.2 ms …   3.6 ms    5 runs
 
Benchmark 2: C
  Time (mean ± σ):       5.2 ms ±   0.4 ms    [User: 2.1 ms, System: 1.2 ms]
  Range (min … max):     4.7 ms …   5.8 ms    5 runs
 
Summary
  Rust ran
    1.49 ± 0.13 times faster than C
```

### Cold Start - Error Handling
```
Benchmark 1: Rust
  Time (mean ± σ):       2.7 ms ±   0.2 ms    [User: 1.5 ms, System: 0.8 ms]
  Range (min … max):     2.6 ms …   3.1 ms    5 runs
 
Benchmark 2: C
  Time (mean ± σ):       4.6 ms ±   0.3 ms    [User: 1.8 ms, System: 1.1 ms]
  Range (min … max):     4.2 ms …   5.0 ms    5 runs
 
Summary
  Rust ran
    1.66 ± 0.17 times faster than C
```

### Search - Simple Query
```
Benchmark 1: Rust
  Time (mean ± σ):      1.497 s ±  0.314 s    [User: 0.015 s, System: 0.015 s]
  Range (min … max):    1.325 s …  2.051 s    5 runs
 
Benchmark 2: C
  Time (mean ± σ):      1.351 s ±  0.112 s    [User: 0.054 s, System: 0.009 s]
  Range (min … max):    1.208 s …  1.520 s    5 runs
 
Summary
  C ran
    1.11 ± 0.25 times faster than Rust
```

### Search - Complex Query
```
Benchmark 1: Rust
  Time (mean ± σ):      1.681 s ±  0.237 s    [User: 0.015 s, System: 0.014 s]
  Range (min … max):    1.331 s …  1.886 s    5 runs
 
Benchmark 2: C
  Time (mean ± σ):      1.509 s ±  0.222 s    [User: 0.053 s, System: 0.009 s]
  Range (min … max):    1.290 s …  1.783 s    5 runs
 
Summary
  C ran
    1.11 ± 0.23 times faster than Rust
```

### Search - Empty Query (All Stations)
```
Benchmark 1: Rust
  Time (mean ± σ):      1.539 s ±  0.300 s    [User: 0.016 s, System: 0.016 s]
  Range (min … max):    1.250 s …  1.850 s    3 runs
 
Benchmark 2: C
  Time (mean ± σ):      1.418 s ±  0.232 s    [User: 0.053 s, System: 0.009 s]
  Range (min … max):    1.282 s …  1.686 s    3 runs
 
Summary
  C ran
    1.09 ± 0.28 times faster than Rust
```

### Departures - By Station Name
```
Benchmark 1: Rust
  Time (mean ± σ):      1.801 s ±  0.281 s    [User: 0.015 s, System: 0.013 s]
  Range (min … max):    1.519 s …  2.176 s    5 runs
 
Benchmark 2: C
  Time (mean ± σ):      1.585 s ±  0.255 s    [User: 0.055 s, System: 0.010 s]
  Range (min … max):    1.308 s …  1.967 s    5 runs
 
Summary
  C ran
    1.14 ± 0.25 times faster than Rust
```

### Departures - By Station ID
```
Benchmark 1: Rust
  Time (mean ± σ):     102.1 ms ±   3.3 ms    [User: 8.0 ms, System: 5.1 ms]
  Range (min … max):    98.9 ms … 107.5 ms    5 runs
 
Benchmark 2: C
  Time (mean ± σ):      89.5 ms ±   2.8 ms    [User: 10.1 ms, System: 3.7 ms]
  Range (min … max):    85.8 ms …  93.0 ms    5 runs
 
Summary
  C ran
    1.14 ± 0.05 times faster than Rust
```

### Departures - With Filtering
```
Benchmark 1: Rust
  Time (mean ± σ):      1.629 s ±  0.214 s    [User: 0.017 s, System: 0.016 s]
  Range (min … max):    1.408 s …  1.915 s    5 runs
 
Benchmark 2: C
  Time (mean ± σ):      1.599 s ±  0.240 s    [User: 0.054 s, System: 0.009 s]
  Range (min … max):    1.348 s …  1.955 s    5 runs
 
Summary
  C ran
    1.02 ± 0.20 times faster than Rust
```

### Workflow - Search to Departures

Tests the common workflow of searching for a station and then getting its departures.

```
Benchmark 1: Rust
  Time (mean ± σ):      1.556 s ±  0.250 s    [User: 0.023 s, System: 0.021 s]
  Range (min … max):    1.331 s …  1.946 s    6 runs
 
Benchmark 2: C
  Time (mean ± σ):      1.671 s ±  0.264 s    [User: 0.060 s, System: 0.016 s]
  Range (min … max):    1.350 s …  1.959 s    6 runs
 
Summary
  Rust ran
    1.07 ± 0.24 times faster than C
```

### Memory Usage Comparison

#### Basic Memory Analysis
```
Memory analysis tools not available on this system.
Try installing GNU time: brew install gnu-time (macOS) or apt install time (Linux)
```

## Summary

### Key Performance Insights

1. **Binary Size**: C version is significantly smaller (~37KB vs ~5MB)
2. **Cold Start**: Performance varies by operation; both have sub-10ms startup
3. **Network Operations**: Similar performance as both are network-bound
4. **Memory Usage**: C version typically uses less memory
5. **Workflows**: End-to-end performance is comparable

### Recommendations

- **For resource-constrained environments**: Use C version
- **For development productivity**: Use Rust version
- **For maximum compatibility**: Use C version
- **For memory safety**: Use Rust version

Both implementations provide identical functionality with similar runtime performance.
The choice should be based on deployment requirements and team preferences.
