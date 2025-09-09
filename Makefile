# Makefile for slq - Stockholm Local Traffic Query Tool
.PHONY: help build build-release test test-blackbox test-integration clean install dev fmt clippy check all

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Build targets
build: ## Build debug version
	cargo build

build-release: ## Build release version
	cargo build --release

# Testing targets
test: test-blackbox test-integration ## Run all tests

test-blackbox: build-release ## Run black box CLI tests
	@echo "Running black box tests..."
	@./scripts/test-blackbox.sh

test-integration: build-release ## Run integration tests
	@echo "Running integration tests..."
	@./scripts/test-integration.sh

# Development targets
dev: fmt clippy test ## Run all development checks

check: ## Check code without building
	cargo check

fmt: ## Format code
	cargo fmt

clippy: ## Run clippy lints
	cargo clippy -- -D warnings

# Utility targets
clean: ## Clean build artifacts
	cargo clean

install: build-release ## Install system-wide (requires sudo)
	@./scripts/install.sh

install-user: build-release ## Install to user directory (~/.local)
	@./scripts/install.sh --user

install-local: build-release ## Install to ./bin for local use
	@mkdir -p bin
	@cp target/release/slq bin/slq
	@echo "Installed slq to ./bin/slq"
	@echo "Make sure ./bin is in your PATH or use the .envrc file"

uninstall: ## Uninstall system-wide installation (requires sudo)
	@./scripts/install.sh --uninstall

uninstall-user: ## Uninstall user installation
	@INSTALL_DIR=$$HOME/.local/bin MAN_DIR=$$HOME/.local/share/man/man1 ./scripts/install.sh --uninstall

# Documentation
docs: ## Generate and open documentation
	cargo doc --open

# Release targets
release-check: ## Check if ready for release
	@echo "Checking release readiness..."
	@cargo check
	@cargo clippy -- -D warnings
	@./scripts/test-blackbox.sh
	@./scripts/test-integration.sh
	@echo "All checks passed - ready for release"



# All checks for CI
all: fmt clippy test ## Run all checks (suitable for CI)

# Quick development cycle
quick: fmt build ## Quick development cycle (format, build)
