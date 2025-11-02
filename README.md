# slq - Storstockholms Lokaltrafik Query

A CLI tool for querying [Storstockholms Lokaltrafik (SL)](https://sl.se) information.

A Rust implementation for performance, safety, and modern tooling.

![Logo](docs/slq-small.png)

## Installation

**System-wide installation:**
```bash
make install
```

This will build the project and install `slq` using `cargo install`.

**Quick Demo:**
```bash
# Search for stations
slq search "Central"

# Get departures from T-Centralen  
slq departures "T-Centralen"

# Filter by transport type
slq departures "T-Centralen" --transport-mode metro

# Get help
slq --help
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
slq departures "T-Centralen" --line 17    # Shows departures for line 17 (Green Line)

# Filter by transport type:
slq departures "T-Centralen" --transport-mode metro    # Tunnelbanan (subway)
slq departures "Odenplan" --transport-mode bus         # Buses (Blåbuss, Närtrafiken)
slq departures "Odenplan" --transport-mode train       # Trains (Pendeltåg, Roslagsbanan)
slq departures "T-Centralen" --transport-mode tram     # Trams (Spårväg City)

# Filter by destination:
slq departures "T-Centralen" --destination "Akalla"    # Only departures going to Akalla
slq departures "T-Centralen" --destination "9001"      # Filter by destination ID
slq departures "Odenplan" --destination "Airport"      # Partial name matching

# Control number of departures shown:
slq departures "T-Centralen" --count 20               # Show 20 departures instead of default 10
slq departures "T-Centralen" --count 5                # Show only 5 departures

# Combine filters:
slq departures "T--Centralen" --line 14 --transport-mode metro --destination "Fruängen" --count 15
```

## Shell Integration

The search command outputs tab-delimited data perfect for shell pipelines:

```bash
# Get the ID for T-Centralen
slq search "T-Centralen" | head -1 | cut -f2

# Find all stations with "central" in the name
slq search "central" | grep -i central

# Get only metro departures from a station
slq departures "T-Centralen" --transport-mode metro

# Check departures for a specific line
slq departures "T-Centralen" --line 17
```

## APIs Used

- **SL Transport API**: For station search and departure information
  - `https://transport.integration.sl.se/v1/sites` - Station directory
  - `https://transport.integration.sl.se/v1/sites/{id}/departures` - Real-time departures

No API key required for these endpoints.

## Dependencies

All dependencies are managed by Cargo, the Rust package manager.

## Development

### Building and Testing

```bash
# Show all available make targets
make help

# Build project
make             # Build release version
make all         # Build release version
make debug       # Build with debug symbols

# Testing
make test        # Run the test suite

# Maintenance
make clean       # Remove build artifacts
```

### Editor Setup

For the best development experience, use `rust-analyzer` with your editor of choice. It provides excellent IntelliSense, error checking, and "go to definition" by reading the `Cargo.toml` file.

- **VS Code**: Install the `rust-analyzer` extension.
- **Vim/Neovim**: Use a plugin manager to install `rust-analyzer`.
- **Emacs**: Use `lsp-mode` with `rust-analyzer`.

### Static Analysis

Use `clippy`, the standard Rust linter, for code quality checks:

```bash
# Run static analysis
cargo clippy

# Run static analysis with automatic fixes (use with caution)
cargo clippy --fix
```

### Implementation Details

This Rust implementation provides:

- **Performance**: Fast execution thanks to Rust's zero-cost abstractions.
- **Memory Safety**: Guaranteed memory safety without a garbage collector.
- **Modern Tooling**: A modern development experience with Cargo, rust-analyzer, and clippy.
- **Robust error handling**: Graceful handling of network and parsing errors.

### Testing

The project includes a test suite managed by Cargo.

```bash
# Run tests
make test
# or
cargo test
```

## Publishing Releases

### Prerequisites

Publishing requires:
- [GitHub CLI (gh)](https://cli.github.com/) installed and authenticated
- Push access to the repository
- Clean git working directory



## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](file:LICENSE) file for details.


