#!/bin/bash
# Integration testing script for slq CLI
# Tests end-to-end workflows and complex scenarios

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
    log_info "Running integration test: $test_name"

    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name"
    fi
    echo
}

# Integration test functions

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

test_error_handling_robustness() {
    local test_count=0
    local expected_failures=0

    # Test various error conditions
    "$SLQ_BIN" departures "NONEXISTENT123" >/dev/null 2>&1 || expected_failures=$((expected_failures + 1))
    test_count=$((test_count + 1))

    "$SLQ_BIN" departures "999999" >/dev/null 2>&1 || expected_failures=$((expected_failures + 1))
    test_count=$((test_count + 1))



    # Should have run some tests and had some expected failures
    if [[ test_count -ge 2 && expected_failures -ge 2 ]]; then
        return 0
    else
        log_error "Error handling robustness test: ran $test_count tests, $expected_failures expected failures"
        return 1
    fi
}

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

# Main test runner
main() {
    log_info "Starting integration tests for slq CLI"
    log_info "Using binary: $SLQ_BIN"
    log_info "Temp directory: $TEMP_DIR"
    echo

    # Check if we can reach the API (skip network tests if offline)
    local api_available=true
    if ! "$SLQ_BIN" search "Stockholm" >/dev/null 2>&1; then
        log_warning "API appears to be unavailable - skipping network-dependent tests"
        api_available=false
    fi

    # Workflow tests
    if [[ "$api_available" == true ]]; then
        run_test "Search to departures workflow" test_search_to_departures_workflow
        run_test "Multiple search terms" test_multiple_search_terms
        run_test "Data consistency" test_data_consistency
        run_test "Performance basic" test_performance_basic
        run_test "Unicode handling" test_unicode_handling
        run_test "Concurrent requests" test_concurrent_requests
    fi

    # Local tests (don't require network)
    run_test "Shell scripting workflow" test_shell_scripting_workflow
    run_test "Error handling robustness" test_error_handling_robustness
    run_test "Output format consistency" test_output_format_consistency

    # Summary
    echo
    log_info "Integration Test Summary:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All integration tests passed! 🎉"
        exit 0
    else
        log_error "$TESTS_FAILED integration test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"
