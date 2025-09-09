# Makefile for slq - Stockholm Local Traffic Query Tool
.PHONY: help build build-release test test-blackbox test-integration clean install install-user install-local uninstall uninstall-user dev fmt clippy check all

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
test: test-cli ## Run all tests

test-cli: build-release ## Run comprehensive CLI tests
	@echo "Running CLI tests..."
	@./scripts/test-cli.sh

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

install: ## Install system-wide (requires sudo)
	@cargo run --bin install

install-user: ## Install to user directory (~/.local)
	@cargo run --bin install -- --user

install-local: build-release ## Install to ./bin for local use
	@mkdir -p bin
	@cp target/release/slq bin/slq
	@echo "Installed slq to ./bin/slq"
	@echo "Make sure ./bin is in your PATH or use the .envrc file"

uninstall: ## Uninstall system-wide installation (requires sudo)
	@cargo run --bin install -- --uninstall

uninstall-user: ## Uninstall user installation
	@cargo run --bin install -- --user --uninstall

# Documentation
docs: ## Generate and open documentation
	cargo doc --open

# Release targets
release-check: ## Check if ready for release
	@echo "Checking release readiness..."
	@cargo check
	@cargo clippy -- -D warnings
	@./scripts/test-cli.sh
	@echo "All checks passed - ready for release"



# All checks for CI
all: fmt clippy test ## Run all checks (suitable for CI)

# Quick development cycle
quick: fmt build ## Quick development cycle (format, build)
