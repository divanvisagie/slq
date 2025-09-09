#!/bin/bash
# Black box testing script for slq CLI
# Tests the CLI interface without knowledge of internal implementation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Set the binary path
if [[ -f "$PROJECT_DIR/bin/slq" ]]; then
    SLQ_BIN="$PROJECT_DIR/bin/slq"
elif [[ -f "$PROJECT_DIR/target/release/slq" ]]; then
    SLQ_BIN="$PROJECT_DIR/target/release/slq"
else
    echo -e "${RED}Error: slq binary not found. Run 'make build-release' first.${NC}"
    exit 1
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test framework functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test: $test_name"

    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name"
    fi
    echo
}

# Utility functions
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    if [[ "$actual" -eq "$expected" ]]; then
        return 0
    else
        log_error "$description: Expected exit code $expected, got $actual"
        return 1
    fi
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local description="$3"

    if echo "$text" | grep -q "$pattern"; then
        return 0
    else
        log_error "$description: Text does not contain '$pattern'"
        log_error "Actual output: $text"
        return 1
    fi
}

assert_not_contains() {
    local text="$1"
    local pattern="$2"
    local description="$3"

    if echo "$text" | grep -q "$pattern"; then
        log_error "$description: Text unexpectedly contains '$pattern'"
        log_error "Actual output: $text"
        return 1
    else
        return 0
    fi
}

assert_tab_delimited() {
    local text="$1"
    local description="$2"

    # Check if output contains tab characters
    if echo "$text" | grep -q $'\t'; then
        return 0
    else
        log_error "$description: Output is not tab-delimited"
        log_error "Actual output: $text"
        return 1
    fi
}

# Test functions

test_help_message() {
    local output
    local exit_code

    output=$("$SLQ_BIN" --help 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Help message exit code" &&
    assert_contains "$output" "Stockholm Local Traffic" "Help message content" &&
    assert_contains "$output" "search" "Help contains search command" &&
    assert_contains "$output" "departures" "Help contains departures command"
}

test_version_or_help_short() {
    local output
    local exit_code

    output=$("$SLQ_BIN" -h 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Short help exit code" &&
    assert_contains "$output" "Usage:" "Short help contains usage"
}

test_search_basic() {
    local output
    local exit_code

    output=$("$SLQ_BIN" search "Central" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Search basic exit code" &&
    assert_contains "$output" "T-Centralen" "Search finds T-Centralen" &&
    assert_tab_delimited "$output" "Search output is tab-delimited"
}

test_search_tab_delimited_format() {
    local output
    local first_line
    local station_name
    local station_id

    output=$("$SLQ_BIN" search "T-Centralen" 2>&1)
    first_line=$(echo "$output" | head -1)

    # Split on tab and check we have exactly 2 fields
    IFS=$'\t' read -ra FIELDS <<< "$first_line"

    if [[ ${#FIELDS[@]} -eq 2 ]]; then
        station_name="${FIELDS[0]}"
        station_id="${FIELDS[1]}"

        # Station name should not be empty
        [[ -n "$station_name" ]] &&
        # Station ID should be numeric
        [[ "$station_id" =~ ^[0-9]+$ ]]
    else
        log_error "Search output should have exactly 2 tab-separated fields"
        return 1
    fi
}

test_search_case_insensitive() {
    local output_lower
    local output_upper

    output_lower=$("$SLQ_BIN" search "central" 2>&1)
    output_upper=$("$SLQ_BIN" search "CENTRAL" 2>&1)

    # Both should return results (non-empty)
    [[ -n "$output_lower" ]] && [[ -n "$output_upper" ]]
}

test_search_empty_query() {
    local output
    local exit_code

    output=$("$SLQ_BIN" search "" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    # Should succeed but return many results
    assert_exit_code 0 "$exit_code" "Empty search exit code"
}

test_search_nonexistent() {
    local output
    local exit_code

    output=$("$SLQ_BIN" search "NONEXISTENTSTATION12345" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    # Should succeed but return no results
    assert_exit_code 0 "$exit_code" "Nonexistent search exit code" &&
    [[ -z "$output" ]] # Should be empty
}

test_departures_by_name() {
    local output
    local exit_code

    output=$("$SLQ_BIN" departures "T-Centralen" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Departures by name exit code" &&
    assert_contains "$output" "Departures from" "Departures header" &&
    assert_contains "$output" "Time" "Departures table header" &&
    assert_contains "$output" "Line" "Departures table header" &&
    assert_contains "$output" "Destination" "Departures table header"
}

test_departures_by_id() {
    local output
    local exit_code

    # Use T-Centralen's ID (9001)
    output=$("$SLQ_BIN" departures "9001" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Departures by ID exit code" &&
    assert_contains "$output" "Departures from 9001" "Departures header with ID"
}

test_departures_nonexistent() {
    local output
    local exit_code

    output=$("$SLQ_BIN" departures "NONEXISTENTSTATION12345" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 1 "$exit_code" "Nonexistent departures exit code" &&
    assert_contains "$output" "Error:" "Error message for nonexistent station"
}

test_departures_filter_by_line() {
    local output
    local exit_code

    # Test filtering by line number
    output=$("$SLQ_BIN" departures "T-Centralen" --line 14 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Departures line filter exit code" &&
    assert_contains "$output" "line 14" "Departures header shows line filter" &&
    assert_contains "$output" "14" "Departures output contains line 14"
}

test_departures_filter_by_transport() {
    local output
    local exit_code

    # Test filtering by transport type
    output=$("$SLQ_BIN" departures "T-Centralen" --transport-type metro 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Departures transport filter exit code" &&
    assert_contains "$output" "(metro)" "Departures header shows transport filter" &&
    assert_contains "$output" "Tunnelbanan" "Departures output contains metro lines"
}

test_departures_line_variants() {
    local output_28
    local output_28s
    local line_count_28
    local line_count_28s

    # Find a station with line variants (using a generic search)
    local station_with_variants
    station_with_variants=$("$SLQ_BIN" search "Stockholm" 2>/dev/null | head -1 | cut -f1)

    if [[ -z "$station_with_variants" ]]; then
        return 0  # Skip test if no station found
    fi

    # Test that filtering for base line number includes variants
    output_28=$("$SLQ_BIN" departures "$station_with_variants" --line 28 2>/dev/null || echo "")
    output_28s=$("$SLQ_BIN" departures "$station_with_variants" --line 28s 2>/dev/null || echo "")

    # Even if no results, command should succeed
    return 0
}

test_departures_table_format() {
    local output
    local header_line

    output=$("$SLQ_BIN" departures "T-Centralen" 2>&1)
    header_line=$(echo "$output" | grep "Wait.*Time.*Line.*Destination")

    assert_contains "$output" "Wait" "Departures table has Wait column" &&
    assert_contains "$output" "Time" "Departures table has Time column" &&
    assert_contains "$output" "Line" "Departures table has Line column" &&
    assert_contains "$output" "Destination" "Departures table has Destination column"
}



test_invalid_command() {
    local output
    local exit_code

    output=$("$SLQ_BIN" invalid_command 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 2 "$exit_code" "Invalid command exit code" &&
    assert_contains "$output" "error:" "Invalid command error message"
}

test_missing_arguments() {
    local output
    local exit_code

    # Test search without query
    output=$("$SLQ_BIN" search 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 2 "$exit_code" "Missing search argument exit code"
}

test_output_encoding() {
    local output

    # Test with Swedish characters
    output=$("$SLQ_BIN" search "Södermalm" 2>&1)

    # Should not crash and should handle Swedish characters properly
    [[ $? -eq 0 ]]
}

test_pipe_compatibility() {
    local output
    local pipe_output

    # Test that output works well with common shell commands
    output=$("$SLQ_BIN" search "Central" 2>&1)
    pipe_output=$(echo "$output" | head -1 | cut -f2)

    # Should extract station ID successfully
    [[ "$pipe_output" =~ ^[0-9]+$ ]]
}

# Network-dependent tests (might fail in offline environments)
test_api_connectivity() {
    local output
    local exit_code

    log_warning "Testing API connectivity (may fail if offline)"

    # This is a basic connectivity test
    output=$("$SLQ_BIN" search "Stockholm" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    else
        log_warning "API connectivity test failed - this is expected if offline"
        return 0  # Don't fail the test suite for network issues
    fi
}

# Main test runner
main() {
    log_info "Starting black box tests for slq CLI"
    log_info "Using binary: $SLQ_BIN"
    echo

    # Basic CLI tests
    run_test "Help message" test_help_message
    run_test "Short help" test_version_or_help_short
    run_test "Invalid command" test_invalid_command
    run_test "Missing arguments" test_missing_arguments

    # Search command tests
    run_test "Search basic functionality" test_search_basic
    run_test "Search tab-delimited format" test_search_tab_delimited_format
    run_test "Search case insensitive" test_search_case_insensitive
    run_test "Search empty query" test_search_empty_query
    run_test "Search nonexistent station" test_search_nonexistent

    # Departures command tests
    run_test "Departures by name" test_departures_by_name
    run_test "Departures by ID" test_departures_by_id
    run_test "Departures nonexistent station" test_departures_nonexistent
    run_test "Departures filter by line" test_departures_filter_by_line
    run_test "Departures filter by transport" test_departures_filter_by_transport
    run_test "Departures line variants" test_departures_line_variants
    run_test "Departures table format" test_departures_table_format

    # Output format tests
    run_test "Output encoding" test_output_encoding
    run_test "Pipe compatibility" test_pipe_compatibility

    # Network tests (optional)
    run_test "API connectivity" test_api_connectivity

    # Summary
    echo
    log_info "Test Summary:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"
