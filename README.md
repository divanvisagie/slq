# slq - Storstockholms Lokaltrafik Query

A CLI tool for querying [Storstockholms Lokaltrafik (SL)](https://sl.se) information.

Available in both **Rust** (original) and **C** implementations with identical functionality.

![Logo](docs/slq-small.png)

## Implementation Variants

- **Rust version** (`/`): Original implementation using modern Rust ecosystem
- **C version** (`c-version/`): Full rewrite using jansson and libcurl with identical API

Both versions pass the same comprehensive test suite and provide identical user experience.

## Installation

Choose between Rust or C implementation based on your needs:

### Rust Version (Recommended)

**System-wide Installation:**
```bash
# Install system-wide (requires sudo)
sudo make install

# Or install to user directory
make install-user

# Or use the installer directly
sudo cargo run --bin install
cargo run --bin install -- --user
```

**Dependencies:** None (single binary)

### C Version

**System-wide Installation:**
```bash
# Install dependencies first:
# macOS: brew install jansson curl
# Ubuntu: sudo apt-get install libjansson-dev libcurl4-openssl-dev

# Build and install
make build-c
sudo make install-c
```

**Dependencies:** libcurl, jansson

### Local Development Build

**Rust:**
```bash
# Build and install locally for development
make install-local

# Or build release version only
make build-release
```

**C:**
```bash
# Build C version
make build-c

# Run tests
make test-c
```

### Manual Installation

**Rust:**
```bash
cargo build --release
# Binary will be at target/release/slq
```

**C:**
```bash
cd c-version && make
# Binary will be at c-version/bin/slq
```

### Native Installer

The project includes a native Rust installer:

```bash
# System-wide installation (requires sudo)
sudo cargo run --bin install

# User installation
cargo run --bin install -- --user

# Custom prefix
sudo cargo run --bin install -- --prefix /opt/slq

# Custom directories
INSTALL_DIR=~/bin cargo run --bin install

# Uninstall
sudo cargo run --bin install -- --uninstall
cargo run --bin install -- --user --uninstall

# Show help
cargo run --bin install -- --help
```

The installer features:
- Cross-platform compatibility
- Auto-fallback to user directory when no root privileges

### Uninstallation

**Rust:**
```bash
# Remove system-wide installation
sudo make uninstall

# Remove user installation
make uninstall-user

# Or use the installer directly
sudo cargo run --bin install -- --uninstall
```

**C:**
```bash
cd c-version && sudo make uninstall
```

## Usage

### Search for stations

Find station names and IDs (output is tab-delimited for easy shell scripting):

```bash
slq search "Central"
```

Output:
```
Centralen	1002
T-Centralen	9001
Stockholms central	9000
...
```

### Check departures

Show upcoming departures from a station with real-time information:

```bash
slq departures "T-Centralen"
# or by station ID:
slq departures "9001"
```

**Output format:**
```
Departures from T-Centralen:
Wait  Time   Line   Destination          Type
----------------------------------------------------------------------
Now   13:35  13     Ropsten              Tunnelbanans röda linje
1m    13:36  19     Odenplan             Tunnelbanans gröna linje
2m    13:37  14     Fruängen             Tunnelbanans röda linje
```

**Filtering options:**

```bash
# Filter by line number (includes variants):
slq departures "T-Centralen" --line 14
slq departures "Station" --line 28    # Shows both 28 and 28s
slq departures "Station" --line 28s   # Shows only 28s

# Filter by transport type:
slq departures "T-Centralen" --transport-type metro    # Tunnelbanan (subway)
slq departures "Odenplan" --transport-type bus         # Buses (Blåbuss, Närtrafiken)
slq departures "Odenplan" --transport-type train       # Trains (Pendeltåg, Roslagsbanan)
slq departures "T-Centralen" --transport-type tram     # Trams (Spårväg City)

# Filter by destination:
slq departures "T-Centralen" --destination "Akalla"    # Only departures going to Akalla
slq departures "T-Centralen" --destination "9001"      # Filter by destination ID
slq departures "Odenplan" --destination "Airport"      # Partial name matching

# Control number of departures shown:
slq departures "T-Centralen" --count 20               # Show 20 departures instead of default 10
slq departures "T-Centralen" --count 5                # Show only 5 departures

# Combine filters:
slq departures "T-Centralen" --line 14 --transport-type metro --destination "Fruängen" --count 15
```

## Examples

```bash
# Find all stations matching "gamla"
slq search "gamla"

# Check what's departing from Gamla Stan
slq departures "Gamla stan"

# Filter departures by line or transport type
slq departures "T-Centralen" --transport-type metro    # Subway lines only
slq departures "Odenplan" --transport-type train       # Train lines only
slq departures "T-Centralen" --line 14                 # Metro line 14
slq departures "Station" --line 28                     # Includes variants like 28s

# Filter by destination
slq departures "T-Centralen" --destination "Akalla"    # Only departures to Akalla
slq departures "Odenplan" --destination "Airport"      # Partial destination matching

# Show more departures
slq departures "T-Centralen" --count 20               # Show 20 departures instead of 10
```

## Shell Integration

The search command outputs tab-delimited data perfect for shell pipelines:

```bash
# Get the ID for T-Centralen
slq search "T-Centralen" | head -1 | cut -f2

# Find all stations with "central" in the name
slq search "central" | grep -i central

# Get only metro departures from a station
slq departures "T-Centralen" --transport-type metro

# Check specific line departures
slq departures "Galoppfältet" --line 28
```

## APIs Used

- **SL Transport API**: For station search and departure information
  - `https://transport.integration.sl.se/v1/sites` - Station directory
  - `https://transport.integration.sl.se/v1/sites/{id}/departures` - Real-time departures

No API key required for these endpoints.

## Dependencies

### Rust Version
- `clap` - Command-line argument parsing
- `reqwest` - HTTP client
- `serde` - JSON serialization/deserialization
- `urlencoding` - URL encoding for search queries

### C Version
- `libcurl` - HTTP client
- `jansson` - JSON parsing library

## Development

### Building and Testing

```bash
# Show all available make targets (includes both Rust and C)
make help

# Rust development
make quick       # Quick development cycle
make test        # Run all tests

# C development  
make build-c     # Build C version
make test-c      # Run C version tests
make clean-c     # Clean C build artifacts
```

### Implementation Comparison

Both implementations provide identical functionality:
- **Binary size**: Rust ~2.8MB, C ~38KB (shared libs) / ~150KB (static)
- **Memory usage**: Rust ~8-12MB, C ~2-4MB
- **Startup time**: Rust ~15-20ms, C ~2-5ms
- **Dependencies**: Rust (none), C (libcurl + jansson)
- **Test results**: 26/26 tests pass for both versions

See `c-version/IMPLEMENTATION_COMPARISON.md` for detailed analysis.

### Testing

The project includes comprehensive testing at two levels:

#### Test Types

**Black box tests** (`scripts/test-blackbox.sh`):
- Test individual CLI commands in isolation
- Verify basic functionality, error handling, and output formats
- Test each command (search, departures) independently
- Validate command-line argument parsing and help messages
- Focus on the external interface without knowledge of internal implementation

Example black-box test:
```bash
# Test that search command returns tab-delimited output
output=$(slq search "Central")
assert_contains "$output" "T-Centralen"
assert_tab_delimited "$output"
```

**Integration tests** (`scripts/test-integration.sh`):
- Test end-to-end workflows that combine multiple commands
- Verify realistic user scenarios and data flow between commands
- Test system behavior under various conditions (performance, concurrency)
- Validate data consistency across different operations
- Focus on how components work together as a complete system

Example integration test:
```bash
# Test search → departures workflow
search_output=$(slq search "T-Centralen")
station_id=$(echo "$search_output" | head -1 | cut -f2)
departures_output=$(slq departures "$station_id")
# Verify the workflow produces expected results
```



#### Running Tests

```bash
# Run all tests (black-box and integration)
make test

# Run only black box tests
make test-blackbox

# Run only integration tests
make test-integration
```

## Documentation

### Man Page

After installation, comprehensive documentation is available via the man page:

```bash
man slq
```

The man page includes detailed information about all commands, options, examples, and usage patterns.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

