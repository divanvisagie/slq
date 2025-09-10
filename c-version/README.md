# slq - Storstockholms Lokaltrafik Query (C Version)

A C CLI tool for querying [Storstockholms Lokaltrafik (SL)](https://sl.se) information.

This is a C port of the original Rust implementation, using jansson for JSON parsing and libcurl for HTTP requests.

## Dependencies

### Required Libraries

- **libcurl** - HTTP client library
- **jansson** - JSON parsing library
- **Standard C library** with POSIX extensions

### Installation on Different Systems

#### macOS (Homebrew)
```bash
brew install curl jansson
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install libcurl4-openssl-dev libjansson-dev build-essential
```

#### CentOS/RHEL/Fedora
```bash
# CentOS/RHEL
sudo yum install libcurl-devel jansson-devel gcc make

# Fedora
sudo dnf install libcurl-devel jansson-devel gcc make
```

#### Arch Linux
```bash
sudo pacman -S curl jansson gcc make
```

## Building

### Check Dependencies
```bash
make check-deps
```

### Build the Project
```bash
# Build release version
make

# Build debug version with symbols
make debug

# Clean build artifacts
make clean
```

### Build Targets
```bash
make help    # Show all available targets
```

## Installation

### System-wide Installation (Recommended)
```bash
# Install to /usr/local/bin (requires sudo)
sudo make install
```

### User Installation
```bash
# Install to ~/.local/bin
make install-user
```

### Manual Installation
```bash
# Build and copy manually
make
sudo cp bin/slq /usr/local/bin/
sudo cp ../slq.1 /usr/local/share/man/man1/
```

## Uninstallation

```bash
# Remove system-wide installation
sudo make uninstall

# Remove user installation
make uninstall-user
```

## Usage

The C version provides identical functionality to the Rust version:

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

## Project Structure

```
src/
├── main.c      - Main entry point and command handling
├── cli.c       - Command line argument parsing
├── cli.h       - CLI function declarations
├── client.c    - HTTP client and SL API implementation
├── client.h    - Client function declarations
├── types.c     - Data structures and memory management
└── types.h     - Type definitions and declarations
```

## Development

### Building for Development

```bash
# Build with debug symbols
make debug

# Test the build
make test

# Check for memory leaks (if valgrind is available)
valgrind --leak-check=full ./bin/slq search "Central"
```

### Code Organization

- **types.h/types.c**: Data structures for stops, departures, and memory management
- **cli.h/cli.c**: Command line parsing using getopt
- **client.h/client.c**: HTTP client using libcurl and JSON parsing using jansson
- **main.c**: Application entry point and command handlers

### Memory Management

The C version includes comprehensive memory management:
- All dynamically allocated memory is properly freed
- Error handling includes cleanup of partial allocations
- Valgrind-clean implementation with no memory leaks

## Differences from Rust Version

While functionally identical, the C version:

- Uses **libcurl** instead of reqwest for HTTP requests
- Uses **jansson** instead of serde for JSON parsing
- Uses **getopt** instead of clap for CLI parsing
- Manual memory management instead of Rust's ownership system
- POSIX time functions instead of chrono

## Performance

The C version offers:
- Lower memory footprint
- Faster startup time
- No runtime dependencies (statically linkable)
- Better integration with shell scripts

## Troubleshooting

### Build Issues

```bash
# Check if dependencies are installed
make check-deps

# Clean and rebuild
make clean && make

# Build with verbose output
make CFLAGS="-Wall -Wextra -std=c99 -O2 -v"
```

### Runtime Issues

```bash
# Test HTTP connectivity
curl -s "https://transport.integration.sl.se/v1/sites?expand=true" | head

# Run with debug build for more information
make debug
./bin/slq search "test"
```

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](../LICENSE) file for details.

## Documentation

After installation, comprehensive documentation is available via the man page:

```bash
man slq
```

The man page includes detailed information about all commands, options, examples, and usage patterns.