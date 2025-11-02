# Project configuration
VERSION = 0.3.0
PREFIX ?= /usr/local
TARGET = slq
CARGO_TARGET_DIR ?= target

# Default target
all:
	cargo build --release --target-dir $(CARGO_TARGET_DIR)

# Install system-wide
install:
	cargo install --path .

# Clean build artifacts
clean:
	cargo clean --target-dir $(CARGO_TARGET_DIR)

# Debug build
debug:
	cargo build --target-dir $(CARGO_TARGET_DIR)

# Run tests
test:
	cargo test --target-dir $(CARGO_TARGET_DIR)


# Show current version
version:
	@echo "Current version: $(VERSION)"

# Complete release workflow: update version and publish
release: test
	@echo "Publishing release..."
	@$(MAKE) publish

# Show help
help:
	@echo "Available targets:"
	@echo "  all          - Build the project (default)"
	@echo "  debug        - Build with debug symbols"
	@echo "  install      - Install system-wide"
	@echo "  clean        - Remove build artifacts"
	@echo "  test         - Run tests"
	@echo "  publish      - Create GitHub release with artifacts"
	@echo "  version      - Show current version information"
	@echo "  release      - Complete release workflow"
	@echo "  help         - Show this help message"

.PHONY: all install clean debug test publish version release help
