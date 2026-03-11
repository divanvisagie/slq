# Project configuration
VERSION = 0.5.0
PREFIX ?= /usr/local
TARGET = slq
CARGO_TARGET_DIR ?= target
SITES_URL ?= https://transport.integration.sl.se/v1/sites
SITES_JSON ?= data/sites.json
SKIP_SITE_REFRESH ?= 0

# Default target
all: maybe-refresh-sites
	cargo build --release --target-dir $(CARGO_TARGET_DIR)

maybe-refresh-sites:
ifeq ($(SKIP_SITE_REFRESH),1)
	@echo "Skipping site snapshot refresh (SKIP_SITE_REFRESH=1)"
else
	@$(MAKE) update-sites
endif

update-sites:
	@mkdir -p $(dir $(SITES_JSON))
	curl -fsSL "$(SITES_URL)" -o "$(SITES_JSON)"
	@echo "Updated $(SITES_JSON) from $(SITES_URL)"

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
	@echo "  update-sites - Refresh bundled site snapshot JSON from SL API"
	@echo "  publish      - Create GitHub release with artifacts"
	@echo "  version      - Show current version information"
	@echo "  release      - Complete release workflow"
	@echo "  help         - Show this help message"

.PHONY: all maybe-refresh-sites update-sites install clean debug test publish version release help
