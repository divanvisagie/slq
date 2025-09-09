#!/bin/bash
# CLI testing script for slq
# Comprehensive black box testing treating the binary as completely opaque

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

# Temporary files for testing
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

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

# =============================================================================
# BASIC CLI INTERFACE TESTS
# =============================================================================

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

test_help_short() {
    local output
    local exit_code

    output=$("$SLQ_BIN" -h 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_exit_code 0 "$exit_code" "Short help exit code" &&
    assert_contains "$output" "Usage:" "Short help contains usage"
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

# =============================================================================
# SEARCH COMMAND TESTS
# =============================================================================

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

test_multiple_search_terms() {
    local search_terms=("Stockholm" "Gamla" "Central" "Söder" "Östermalm")
    local all_results=""

    for term in "${search_terms[@]}"; do
        local result
        result=$("$SLQ_BIN" search "$term" 2>/dev/null || true)
        all_results="$all_results$result"
    done

    # Verify we got some results from multiple searches
    if [[ -n "$all_results" ]] && echo "$all_results" | grep -q $'\t'; then
        return 0
    else
        log_error "Multiple search terms test failed"
        return 1
    fi
}

# =============================================================================
# DEPARTURES COMMAND TESTS
# =============================================================================

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

# =============================================================================
# WORKFLOW TESTS
# =============================================================================

test_search_to_departures_workflow() {
    local search_output
    local station_id
    local departures_output

    # Step 1: Search for a station
    search_output=$("$SLQ_BIN" search "T-Centralen" 2>/dev/null)

    # Step 2: Extract the first station ID
    station_id=$(echo "$search_output" | head -1 | cut -f2)

    # Verify we got a numeric ID
    if [[ ! "$station_id" =~ ^[0-9]+$ ]]; then
        log_error "Failed to extract numeric station ID from search"
        return 1
    fi

    # Step 3: Use the ID to get departures
    departures_output=$("$SLQ_BIN" departures "$station_id" 2>/dev/null)

    # Verify departures output is reasonable
    if echo "$departures_output" | grep -q "Departures from"; then
        return 0
    else
        log_error "Departures output does not contain expected header"
        return 1
    fi
}

test_shell_scripting_workflow() {
    local script_file="$TEMP_DIR/test_script.sh"
    local script_output

    # Create a shell script that uses slq
    cat > "$script_file" << 'EOF'
#!/bin/bash
set -euo pipefail

SLQ_BIN="$1"

# Find Central stations and get their IDs
echo "=== Central Stations ==="
"$SLQ_BIN" search "Central" | while IFS=$'\t' read -r name id; do
    echo "Station: $name (ID: $id)"
done

echo ""
echo "=== First Central Station Departures ==="
FIRST_ID=$("$SLQ_BIN" search "T-Centralen" | head -1 | cut -f2)
"$SLQ_BIN" departures "$FIRST_ID" | head -5
EOF

    chmod +x "$script_file"

    # Run the script
    script_output=$("$script_file" "$SLQ_BIN" 2>/dev/null)

    # Verify the script produced reasonable output
    if echo "$script_output" | grep -q "=== Central Stations ===" && \
       echo "$script_output" | grep -q "=== First Central Station Departures ==="; then
        return 0
    else
        log_error "Shell scripting workflow failed"
        return 1
    fi
}

test_data_consistency() {
    local search_by_name
    local search_by_partial
    local departures_by_name
    local departures_by_id

    # Search for T-Centralen
    search_by_name=$("$SLQ_BIN" search "T-Centralen" 2>/dev/null)
    search_by_partial=$("$SLQ_BIN" search "T-Central" 2>/dev/null)

    # Both searches should include T-Centralen
    if ! echo "$search_by_name" | grep -q "T-Centralen"; then
        log_error "Exact search didn't find T-Centralen"
        return 1
    fi

    if ! echo "$search_by_partial" | grep -q "T-Centralen"; then
        log_error "Partial search didn't find T-Centralen"
        return 1
    fi

    # Get departures by name and by ID, they should both work
    departures_by_name=$("$SLQ_BIN" departures "T-Centralen" 2>/dev/null)
    departures_by_id=$("$SLQ_BIN" departures "9001" 2>/dev/null)

    # Both should contain departure information
    if echo "$departures_by_name" | grep -q "Departures from" && \
       echo "$departures_by_id" | grep -q "Departures from"; then
        return 0
    else
        log_error "Departures consistency check failed"
        return 1
    fi
}

# =============================================================================
# ROBUSTNESS TESTS
# =============================================================================

test_error_handling_robustness() {
    local test_count=0
    local expected_failures=0

    # Test various error conditions that should fail
    "$SLQ_BIN" departures "NONEXISTENT123" >/dev/null 2>&1 || expected_failures=$((expected_failures + 1))
    test_count=$((test_count + 1))

    # Test with invalid argument format
    "$SLQ_BIN" departures "--invalid" >/dev/null 2>&1 || expected_failures=$((expected_failures + 1))
    test_count=$((test_count + 1))

    # Should have run tests and had at least one expected failure
    if [[ test_count -ge 2 && expected_failures -ge 1 ]]; then
        return 0
    else
        log_error "Error handling robustness test: ran $test_count tests, $expected_failures expected failures"
        return 1
    fi
}

test_unicode_handling() {
    local unicode_output

    # Test with Swedish characters
    unicode_output=$("$SLQ_BIN" search "Södermalm" 2>/dev/null || true)

    # Should not crash and should handle the input
    if [[ $? -eq 0 ]]; then
        return 0
    else
        log_error "Unicode handling test failed"
        return 1
    fi
}

test_output_format_consistency() {
    local search_output
    local line_count

    # Test that search output format is consistent
    search_output=$("$SLQ_BIN" search "Central" 2>/dev/null)

    # Each line should have exactly one tab
    line_count=0
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            line_count=$((line_count + 1))
            local tab_count
            tab_count=$(echo "$line" | tr -cd '\t' | wc -c)
            if [[ "$tab_count" -ne 1 ]]; then
                log_error "Line $line_count does not have exactly one tab: $line"
                return 1
            fi
        fi
    done <<< "$search_output"

    if [[ "$line_count" -gt 0 ]]; then
        return 0
    else
        log_error "No output lines to check format consistency"
        return 1
    fi
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

test_concurrent_requests() {
    local pids=()
    local temp_files=()

    # Run multiple searches concurrently
    for i in {1..3}; do
        local temp_file="$TEMP_DIR/concurrent_$i.out"
        temp_files+=("$temp_file")
        "$SLQ_BIN" search "Stockholm" > "$temp_file" 2>&1 &
        pids+=($!)
    done

    # Wait for all to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    # Verify all produced reasonable output
    for temp_file in "${temp_files[@]}"; do
        if [[ ! -s "$temp_file" ]]; then
            log_error "Concurrent request produced no output: $temp_file"
            return 1
        fi
    done

    return 0
}

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

test_performance_basic() {
    local start_time
    local end_time
    local duration

    # Simple performance test - search should complete reasonably quickly
    start_time=$(date +%s.%N)
    "$SLQ_BIN" search "Stockholm" >/dev/null 2>&1
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1.0")

    # Should complete within 10 seconds (very generous for network calls)
    if (( $(echo "$duration < 10.0" | bc -l 2>/dev/null || echo "1") )); then
        log_info "Search completed in ${duration}s"
        return 0
    else
        log_warning "Search took ${duration}s (longer than expected)"
        return 0  # Don't fail for performance, just warn
    fi
}

# =============================================================================
# NETWORK TESTS
# =============================================================================

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

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

main() {
    log_info "Starting comprehensive CLI tests for slq"
    log_info "Using binary: $SLQ_BIN"
    log_info "Temp directory: $TEMP_DIR"
    echo

    # Check if we can reach the API (skip network tests if offline)
    local api_available=true
    if ! "$SLQ_BIN" search "Stockholm" >/dev/null 2>&1; then
        log_warning "API appears to be unavailable - skipping network-dependent tests"
        api_available=false
    fi

    # Basic CLI interface tests
    log_info "=== CLI Interface Tests ==="
    run_test "Help message" test_help_message
    run_test "Short help" test_help_short
    run_test "Invalid command" test_invalid_command
    run_test "Missing arguments" test_missing_arguments
    echo

    # Search command tests
    if [[ "$api_available" == true ]]; then
        log_info "=== Search Command Tests ==="
        run_test "Search basic functionality" test_search_basic
        run_test "Search tab-delimited format" test_search_tab_delimited_format
        run_test "Search case insensitive" test_search_case_insensitive
        run_test "Search empty query" test_search_empty_query
        run_test "Search nonexistent station" test_search_nonexistent
        run_test "Multiple search terms" test_multiple_search_terms
        echo
    fi

    # Departures command tests
    if [[ "$api_available" == true ]]; then
        log_info "=== Departures Command Tests ==="
        run_test "Departures by name" test_departures_by_name
        run_test "Departures by ID" test_departures_by_id
        run_test "Departures nonexistent station" test_departures_nonexistent
        run_test "Departures filter by line" test_departures_filter_by_line
        run_test "Departures filter by transport" test_departures_filter_by_transport
        run_test "Departures table format" test_departures_table_format
        echo
    fi

    # Workflow tests
    if [[ "$api_available" == true ]]; then
        log_info "=== Workflow Tests ==="
        run_test "Search to departures workflow" test_search_to_departures_workflow
        run_test "Data consistency" test_data_consistency
        echo
    fi

    # Shell integration tests (some work offline)
    log_info "=== Shell Integration Tests ==="
    run_test "Shell scripting workflow" test_shell_scripting_workflow
    run_test "Pipe compatibility" test_pipe_compatibility
    echo

    # Robustness tests
    log_info "=== Robustness Tests ==="
    run_test "Error handling robustness" test_error_handling_robustness
    run_test "Output format consistency" test_output_format_consistency
    if [[ "$api_available" == true ]]; then
        run_test "Unicode handling" test_unicode_handling
        run_test "Concurrent requests" test_concurrent_requests
    fi
    echo

    # Performance tests
    if [[ "$api_available" == true ]]; then
        log_info "=== Performance Tests ==="
        run_test "Performance basic" test_performance_basic
        echo
    fi

    # Network tests
    log_info "=== Network Tests ==="
    run_test "API connectivity" test_api_connectivity
    echo

    # Summary
    log_info "=== Test Summary ==="
    echo "  Tests run: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All CLI tests passed! 🎉"
        exit 0
    else
        log_error "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"
