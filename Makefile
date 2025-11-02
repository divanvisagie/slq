# Project configuration
VERSION = 0.3.0
PREFIX ?= /usr/local
TARGET = slq
CARGO_TARGET_DIR ?= target

# Default target
all:
	cargo build --release --target-dir $(CARGO_TARGET_DIR)

# Install system-wide
install: all
	sudo mkdir -p $(PREFIX)/bin $(PREFIX)/share/man/man1
	sudo cp $(CARGO_TARGET_DIR)/release/$(TARGET) $(PREFIX)/bin/
	sudo cp slq.1 $(PREFIX)/share/man/man1/

# Install to user directory
install-user: all
	mkdir -p $(HOME)/.local/bin
	mkdir -p $(HOME)/.local/share/man/man1
	cp $(CARGO_TARGET_DIR)/release/$(TARGET) $(HOME)/.local/bin/
	cp slq.1 $(HOME)/.local/share/man/man1/

# Uninstall system-wide
uninstall:
	sudo rm -f $(PREFIX)/bin/$(TARGET)
	sudo rm -f $(PREFIX)/share/man/man1/slq.1

# Uninstall from user directory
uninstall-user:
	rm -f $(HOME)/.local/bin/$(TARGET)
	rm -f $(HOME)/.local/share/man/man1/slq.1

# Clean build artifacts
clean:
	cargo clean --target-dir $(CARGO_TARGET_DIR)

# Debug build
debug:
	cargo build --target-dir $(CARGO_TARGET_DIR)

# Run tests
test:
	cargo test --target-dir $(CARGO_TARGET_DIR)

# Publish release to GitHub
publish:
	@./scripts/publish.sh $(VERSION)

# Update man page version to match Makefile VERSION
update-version:
	@echo "Updating man page version to $(VERSION)..."
	@sed -i.bak 's/slq [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/slq $(VERSION)/' slq.1
	@rm -f slq.1.bak
	@echo "Updated slq.1 with version $(VERSION)"

# Show current version
version:
	@echo "Current version: $(VERSION)"

# Complete release workflow: update version and publish
release: update-version test
	@echo "Publishing release..."
	@$(MAKE) publish

# Show help
help:
	@echo "Available targets:"
	@echo "  all          - Build the project (default)"
	@echo "  debug        - Build with debug symbols"
	@echo "  install      - Install system-wide (requires sudo)"
	@echo "  install-user - Install to user directory"
	@echo "  uninstall    - Remove system-wide installation"
	@echo "  uninstall-user - Remove user installation"
	@echo "  clean        - Remove build artifacts"
	@echo "  test         - Run tests"
	@echo "  publish      - Create GitHub release with artifacts"
	@echo "  update-version - Update man page version to match Makefile"
	@echo "  version      - Show current version information"
	@echo "  release      - Complete release workflow (update version + publish)"
	@echo "  help         - Show this help message"

.PHONY: all install install-user uninstall uninstall-user clean debug test publish update-version version release help

