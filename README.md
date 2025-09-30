# slq - Storstockholms Lokaltrafik Query

A CLI tool for querying [Storstockholms Lokaltrafik (SL)](https://sl.se) information.

A C implementation using libcurl and jansson for maximum compatibility and minimal footprint.

![Logo](docs/slq-small.png)



## Installation

### Quick Start

**Install slq (One Command):**
```bash
./install.sh
```

That's it! This automatically:
- Installs all dependencies
- Configures the build 
- Compiles the project
- Runs tests
- Installs slq system-wide

**Other Options:**
```bash
./install.sh --user       # Install to ~/.local instead of system-wide
./install.sh --dev        # Development setup with debugging tools
```

> **Note:** No manual dependency installation needed! The installer detects your system and handles everything automatically.

**Quick Demo:**
```bash
# Search for stations
slq search "Central"

# Get departures from T-Centralen  
slq departures "T-Centralen"

# Filter by transport type
slq departures "T-Centralen" --transport-type metro

# Get help
slq --help
man slq
```

### Installation Options

**One-Command Setup (Recommended):**
```bash
./install.sh              # System-wide installation
./install.sh --user       # User installation (~/.local)
./install.sh --dev        # Development setup
```

**Manual Configuration:**
```bash
./configure                 # Auto-install dependencies and configure
make                        # Build
sudo make install          # Install system-wide
# OR
make install-user          # Install to ~/.local
```

**Configuration Options:**
- `--no-auto-install` - Don't automatically install missing dependencies  
- `--prefix=DIR` - Installation prefix (default: `/usr/local`)
- `--enable-debug` - Build with debug symbols and debugging info
- `--enable-sanitizers` - Enable AddressSanitizer and UBSan for development
- `--enable-static` - Build static binary (experimental)
- `--cc=COMPILER` - Use specific C compiler
- `--verbose` - Show detailed dependency information

**Just Build (No Install):**
```bash
./configure                 # Set up build environment with dependencies
make                        # Build binary
./bin/slq --help           # Use directly from build directory
```

The configure script automatically detects your system and installs:
- C compiler (gcc, clang, etc.)
- pkg-config
- jansson (JSON library) 
- libcurl (HTTP library)
- make

### Uninstallation

```bash
# Remove system-wide installation
sudo make uninstall

# Remove user installation
make uninstall-user
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

- `libcurl` - HTTP client library
- `jansson` - JSON parsing library

## Development

### Building and Testing

```bash
# Show all available make targets
make help

# Build project
make             # Build debug version
make debug       # Build with debug symbols

# Testing
make test        # Run basic functionality test
make check-deps  # Verify dependencies are installed

# Maintenance
make clean       # Remove build artifacts
```

### Editor Setup

For the best development experience, generate a `compile_commands.json` file that tells your editor where to find external libraries like `jansson` and `libcurl`:

```bash
# Generate compile_commands.json for editor support
make compile-commands
```

This creates a `compile_commands.json` file that provides your editor with:
- Include paths for external libraries (`-I/opt/homebrew/Cellar/jansson/...`)
- Compiler flags (`-Wall`, `-Wextra`, `-std=c99`, etc.)
- Complete build context for each source file

**Editor compatibility:**
- **VS Code**: Install the C/C++ extension - automatically reads `compile_commands.json`
- **Vim/Neovim**: Use `clangd` LSP server
- **Emacs**: Use `lsp-mode` with `clangd`  
- **CLion/Qt Creator**: Import the `compile_commands.json` file

After generating the file and restarting your editor, you should get proper IntelliSense, error checking, and "go to definition" for all library functions.

### Static Analysis

The project includes clang-tidy configuration for code quality checks:

```bash
# Run static analysis
make lint

# Run static analysis with automatic fixes (use with caution)
make lint-fix
```

The `.clang-tidy` configuration enforces:
- Standard C naming conventions (CamelCase_t for typedefs)
- Code quality checks (bug detection, performance, readability)
- Security best practices

### Memory Testing

The project includes comprehensive memory testing using clang sanitizers, which are cross-platform and built into the compiler:

```bash
# Build and test with AddressSanitizer (detects buffer overflows, use-after-free)
make test-asan

# Build and test with UndefinedBehaviorSanitizer (detects undefined behavior)
make test-ubsan

# Build and test with combined sanitizers (recommended)
make test-sanitize
```

**What the sanitizers detect:**
- **AddressSanitizer (ASan)**: Buffer overflows, use-after-free, heap corruption, stack overflows
- **UndefinedBehaviorSanitizer (UBSan)**: Integer overflows, null pointer dereferences, unaligned memory access

**Advantages over valgrind:**
- Cross-platform (works on macOS, Linux, Windows)
- Faster execution (2-3x slowdown vs 10-50x for valgrind)
- Better error messages with source locations
- Built into clang and gcc

The sanitizer tests are automatically included in `make test-all` for comprehensive validation.

### Implementation Details

This C implementation provides:

- **Minimal footprint**: ~37KB binary size
- **Fast compilation**: ~0.25s build time  
- **Universal compatibility**: Works on any system with libcurl and jansson
- **Memory safe**: Comprehensive manual memory management (valgrind clean)
- **Robust error handling**: Graceful handling of network and parsing errors

### Testing

The project includes comprehensive CLI testing:

```bash
# Run comprehensive test suite
./tests/test-cli.sh

# Run basic functionality test  
./tests/test.sh

# Or use make targets
make test-cli     # Run comprehensive CLI tests
make test-basic   # Run basic functionality test
make test-all     # Run all tests
```

Tests cover:
- Basic CLI functionality and help messages
- Station search with various queries
- Departures with filtering options
- Error handling and edge cases
- Shell integration scenarios

## Publishing Releases

### Prerequisites

Publishing requires:
- Configured build environment (`./configure` completed successfully)
- [GitHub CLI (gh)](https://cli.github.com/) installed and authenticated
- Push access to the repository
- Clean git working directory (or use `--force`)

The configure script will check for GitHub CLI and show its status.
If needed, install manually: `brew install gh` / `sudo apt install gh`, then `gh auth login`

### Version Management

The project version is centrally managed in the Makefile:

```makefile
# Project configuration
VERSION = 0.1.0
```

#### Version Commands

```bash
# Show current version info
make version

# Update man page to match Makefile version
make update-version

# Complete release workflow (update version + tests + publish)
make release
```

### Publishing Commands

```bash
# Quick release with current Makefile version
make release

# Preview what would be published (dry-run)
make publish-dry

# Publish current Makefile version
make publish

# Publish a specific version (overrides Makefile)
make publish-version VERSION=1.2.3

# Manual script usage with options
./scripts/publish.sh --help
./scripts/publish.sh --dry-run
./scripts/publish.sh --force v1.2.3
```

### Release Workflow

**Option 1: Quick Release**
```bash
# Edit VERSION in Makefile
vim Makefile  # Change VERSION = 0.1.0 to VERSION = 0.2.0

# Complete release workflow
make release  # Updates man page, runs tests, publishes
```

**Option 2: Step-by-step**
```bash
# 1. Update version in Makefile
# 2. Sync man page with Makefile version
make update-version

# 3. Test everything works
make test-all

# 4. Publish release
make publish
```

### Release Process

The release system automatically:

1. **Uses Makefile VERSION** as the source of truth
2. **Updates man page** to match Makefile version (`make update-version`)
3. **Validates environment** (git status, branch, gh CLI)
4. **Builds release artifacts** (`make clean && make all`)
5. **Runs tests** to ensure quality (`make test-basic`)
6. **Creates archive** with binary, man page, README, and LICENSE
7. **Creates git tag** and pushes to GitHub
8. **Creates GitHub release** with generated release notes and attached archive

### Archive Contents

Each release includes a platform-specific archive (e.g., `slq-v1.2.3-darwin-arm64.tar.gz`):
- `slq` - Compiled binary
- `slq.1` - Manual page
- `README.md` - Full documentation
- `LICENSE` - License file

### Version Synchronization

The system keeps versions synchronized between:
- **Makefile** (`VERSION = x.y.z`) - Source of truth
- **Man page** (`slq.1`) - Updated by `make update-version`
- **Git tags** - Created during publishing
- **GitHub releases** - Created with proper version numbering

To change the version:
1. Edit the `VERSION` variable in the Makefile
2. Run `make update-version` to sync the man page
3. Use `make release` for the complete workflow

## Documentation

### Man Page

After installation, comprehensive documentation is available via the man page:

```bash
man slq
```

The man page includes detailed information about all commands, options, examples, and usage patterns.

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

