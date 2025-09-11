CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 $(shell pkg-config --cflags jansson libcurl)
LIBS = $(shell pkg-config --libs jansson libcurl)
SRCDIR = src
BUILDDIR = build
BINDIR = bin
TARGET = slq

# Source files
SOURCES = $(wildcard $(SRCDIR)/*.c)
OBJECTS = $(SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)

# Default target
all: $(BINDIR)/$(TARGET)

# Create directories
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

# Link the final executable
$(BINDIR)/$(TARGET): $(OBJECTS) | $(BINDIR)
	$(CC) $(OBJECTS) -o $@ $(LIBS)

# Compile source files
$(BUILDDIR)/%.o: $(SRCDIR)/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Install system-wide
install: $(BINDIR)/$(TARGET)
	sudo cp $(BINDIR)/$(TARGET) /usr/local/bin/
	sudo cp slq.1 /usr/local/share/man/man1/

# Install to user directory
install-user: $(BINDIR)/$(TARGET)
	mkdir -p $(HOME)/.local/bin
	mkdir -p $(HOME)/.local/share/man/man1
	cp $(BINDIR)/$(TARGET) $(HOME)/.local/bin/
	cp slq.1 $(HOME)/.local/share/man/man1/

# Uninstall system-wide
uninstall:
	sudo rm -f /usr/local/bin/$(TARGET)
	sudo rm -f /usr/local/share/man/man1/slq.1

# Uninstall from user directory
uninstall-user:
	rm -f $(HOME)/.local/bin/$(TARGET)
	rm -f $(HOME)/.local/share/man/man1/slq.1

# Clean build artifacts
clean:
	rm -rf $(BUILDDIR) $(BINDIR)

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: $(BINDIR)/$(TARGET)

# Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@pkg-config --exists jansson || (echo "Error: jansson not found. Install with: brew install jansson (macOS) or apt-get install libjansson-dev (Ubuntu)" && exit 1)
	@pkg-config --exists libcurl || (echo "Error: libcurl not found. Install with: brew install curl (macOS) or apt-get install libcurl4-openssl-dev (Ubuntu)" && exit 1)
	@echo "All dependencies found."
	@echo "Jansson flags: $(shell pkg-config --cflags jansson)"
	@echo "Jansson libs: $(shell pkg-config --libs jansson)"
	@echo "Curl flags: $(shell pkg-config --cflags libcurl)"
	@echo "Curl libs: $(shell pkg-config --libs libcurl)"

# Test build
test: debug
	./$(BINDIR)/$(TARGET) --help

# Run comprehensive test suite
test-cli: $(BINDIR)/$(TARGET)
	@./tests/test-cli.sh

# Run basic functionality test
test-basic: $(BINDIR)/$(TARGET)
	@./tests/test.sh

# Run all tests
test-all:
	@echo "Running all tests..."
	@echo "===================="
	@failed=0; \
	echo "Running comprehensive CLI tests..."; \
	if ! $(MAKE) test-cli; then \
		echo "CLI tests failed"; \
		failed=$$((failed + 1)); \
	fi; \
	echo ""; \
	echo "Running basic functionality tests..."; \
	if ! $(MAKE) test-basic; then \
		echo "Basic tests failed"; \
		failed=$$((failed + 1)); \
	fi; \
	echo ""; \
	echo "==================== TEST SUMMARY ===================="; \
	if [ $$failed -eq 0 ]; then \
		echo "✓ All test suites passed!"; \
	else \
		echo "✗ $$failed test suite(s) failed"; \
		exit 1; \
	fi

# Run clang-tidy static analysis
lint:
	@echo "Running clang-tidy static analysis..."
	@/opt/homebrew/opt/llvm/bin/clang-tidy $(SRCDIR)/*.c -- $(CFLAGS)

# Run clang-tidy with fixes
lint-fix:
	@echo "Running clang-tidy with automatic fixes..."
	@/opt/homebrew/opt/llvm/bin/clang-tidy $(SRCDIR)/*.c --fix -- $(CFLAGS)

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
	@echo "  check-deps   - Check if dependencies are installed"
	@echo "  test         - Build and run basic test"
	@echo "  test-cli     - Run comprehensive CLI test suite"
	@echo "  test-basic   - Run basic functionality test"
	@echo "  test-all     - Run all tests"
	@echo "  lint         - Run clang-tidy static analysis"
	@echo "  lint-fix     - Run clang-tidy with automatic fixes"
	@echo "  help         - Show this help message"

.PHONY: all install install-user uninstall uninstall-user clean debug check-deps test test-cli test-basic test-all lint lint-fix help
