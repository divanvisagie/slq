#!/bin/bash

# Simple test script for slq C version
# This script performs basic functionality tests

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLQ_BIN="$SCRIPT_DIR/bin/slq"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Function to print test status
print_test() {
    local test_name="$1"
    local status="$2"
    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
    fi
}

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"

    echo -n "Running: $test_name... "

    if output=$(eval "$command" 2>&1); then
        if [[ "$output" =~ $expected_pattern ]]; then
            print_test "$test_name" "PASS"
            return 0
        else
            print_test "$test_name" "FAIL"
            echo "  Expected pattern: $expected_pattern"
            echo "  Got: $output"
            return 1
        fi
    else
        print_test "$test_name" "FAIL"
        echo "  Command failed: $command"
        echo "  Output: $output"
        return 1
    fi
}

echo "Starting slq C version tests..."
echo "=================================="

# Check if binary exists
if [ ! -f "$SLQ_BIN" ]; then
    echo -e "${RED}Error: slq binary not found at $SLQ_BIN${NC}"
    echo "Please run 'make' first to build the project."
    exit 1
fi

# Test 1: Help command
run_test "Help command" \
    "$SLQ_BIN 2>&1 || true" \
    "Usage:.*slq.*command.*options"

# Test 2: Search command basic functionality
run_test "Search command - basic" \
    "$SLQ_BIN search Central" \
    "T-Centralen.*9001"

# Test 3: Search command - case insensitive
run_test "Search command - case insensitive" \
    "$SLQ_BIN search central" \
    "T-Centralen.*9001"

# Test 4: Search command - partial match
run_test "Search command - partial match" \
    "$SLQ_BIN search Gamla" \
    "Gamla.*[0-9]+"

# Test 5: Search command - tab delimited output
run_test "Search command - tab delimited" \
    "$SLQ_BIN search T-Centralen | head -1" \
    "T-Centralen[[:space:]]9001"

# Test 6: Departures command basic functionality
run_test "Departures command - basic" \
    "$SLQ_BIN departures T-Centralen --count 3" \
    "Departures from T-Centralen"

# Test 7: Departures command with station ID
run_test "Departures command - station ID" \
    "$SLQ_BIN departures 9001 --count 2" \
    "Departures from 9001"

# Test 8: Departures command with metro filter
run_test "Departures command - metro filter" \
    "$SLQ_BIN departures T-Centralen --transport-type metro --count 2" \
    "Departures from T-Centralen.*metro"

# Test 9: Departures command with line filter
run_test "Departures command - line filter" \
    "$SLQ_BIN departures T-Centralen --line 14 --count 2" \
    "Departures from T-Centralen.*line 14"

# Test 10: Departures command with count parameter
run_test "Departures command - count parameter" \
    "$SLQ_BIN departures T-Centralen --count 1" \
    "Departures from T-Centralen"

# Test 11: Invalid command handling
run_test "Invalid command handling" \
    "$SLQ_BIN invalid_command 2>&1 || true" \
    "Error:.*unknown command"

# Test 12: Missing arguments handling
run_test "Missing arguments - search" \
    "$SLQ_BIN search 2>&1 || true" \
    "Error:.*requires.*query"

# Test 13: Missing arguments handling - departures
run_test "Missing arguments - departures" \
    "$SLQ_BIN departures 2>&1 || true" \
    "Error:.*requires.*station"

# Test 14: Help for specific commands
run_test "Departures help" \
    "$SLQ_BIN departures --help 2>&1 || true" \
    "Usage:.*departures.*station"

echo ""
echo "=================================="
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo "  Tests passed: $TESTS_PASSED"
echo "  Tests failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
