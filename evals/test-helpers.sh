#!/usr/bin/env bash
# Shared test helpers for Pulz evaluation suite

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$EVALS_DIR")"
RESULTS_DIR="$EVALS_DIR/results"
mkdir -p "$RESULTS_DIR"

# Run Claude with Pulz skill loaded
run_with_pulz() {
    local prompt="$1"
    local fixture="${2:-}"
    local timeout="${3:-120}"

    local cmd_args=(
        claude
        --skill-dir "$PROJECT_DIR/pulz"
        --dangerously-skip-permissions
        --output-format stream-json
        --max-turns 3
    )

    if [[ -n "$fixture" ]]; then
        cmd_args+=(--file "$EVALS_DIR/$fixture")
    fi

    timeout "$timeout" "${cmd_args[@]}" "$prompt" 2>/dev/null || true
}

# Run Claude WITHOUT Pulz skill (baseline)
run_without_pulz() {
    local prompt="$1"
    local fixture="${2:-}"
    local timeout="${3:-120}"

    local cmd_args=(
        claude
        --dangerously-skip-permissions
        --output-format stream-json
        --max-turns 3
    )

    if [[ -n "$fixture" ]]; then
        cmd_args+=(--file "$EVALS_DIR/$fixture")
    fi

    timeout "$timeout" "${cmd_args[@]}" "$prompt" 2>/dev/null || true
}

# Extract text content from stream-json output
extract_text() {
    local json_output="$1"
    echo "$json_output" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null || echo "$json_output"
}

# Check if skill was triggered (appears in stream-json output)
check_skill_triggered() {
    local output="$1"
    echo "$output" | grep -qi "pulz\|palpation\|observation.*listening.*inquiry\|wang-zhen\|wen-zhen\|qie-zhen\|si-zhen\|diagnosis report\|bug profile" && return 0 || return 1
}

# Assert output contains a pattern (case-insensitive)
assert_contains() {
    local label="$1"
    local output="$2"
    local pattern="$3"

    if echo "$output" | grep -qi "$pattern"; then
        echo -e "  ${GREEN}PASS${NC}: $label (found: $pattern)"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: $label (missing: $pattern)"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Assert output does NOT contain a pattern
assert_not_contains() {
    local label="$1"
    local output="$2"
    local pattern="$3"

    if echo "$output" | grep -qi "$pattern"; then
        echo -e "  ${RED}FAIL${NC}: $label (unexpected: $pattern)"
        ((FAIL_COUNT++))
        return 1
    else
        echo -e "  ${GREEN}PASS${NC}: $label (correctly absent: $pattern)"
        ((PASS_COUNT++))
        return 0
    fi
}

# Assert skill was triggered
assert_skill_triggered() {
    local label="$1"
    local output="$2"

    if check_skill_triggered "$output"; then
        echo -e "  ${GREEN}PASS${NC}: $label -- skill triggered"
        ((PASS_COUNT++))
    else
        echo -e "  ${RED}FAIL${NC}: $label -- skill NOT triggered"
        ((FAIL_COUNT++))
    fi
}

# Assert skill was NOT triggered
assert_skill_not_triggered() {
    local label="$1"
    local output="$2"

    if check_skill_triggered "$output"; then
        echo -e "  ${RED}FAIL${NC}: $label -- skill incorrectly triggered"
        ((FAIL_COUNT++))
    else
        echo -e "  ${GREEN}PASS${NC}: $label -- skill correctly not triggered"
        ((PASS_COUNT++))
    fi
}

# Count keyword matches in output
count_matches() {
    local output="$1"
    local pattern="$2"
    echo "$output" | grep -oi "$pattern" | wc -l | tr -d ' '
}

# Score diagnostic structure (0-5 points)
score_diagnostic_structure() {
    local output="$1"
    local score=0

    # Check for four-phase structure
    echo "$output" | grep -qi "observation\|wang.zhen\|static.*analy" && ((score++)) || true
    echo "$output" | grep -qi "listening\|wen.zhen\|log\|runtime\|error.*message\|stack.*trace" && ((score++)) || true
    echo "$output" | grep -qi "inquiry\|context\|environment\|when.*appear\|reproduce" && ((score++)) || true
    echo "$output" | grep -qi "palpation\|qie.zhen\|test\|reproduc\|trace.*data\|variable.*state" && ((score++)) || true

    # Check for structured diagnosis
    echo "$output" | grep -qi "root.*cause\|underlying\|ben\|biao\|symptom.*vs\|bug.*profile" && ((score++)) || true

    echo "$score"
}

# Score fix quality (0-5 points)
score_fix_quality() {
    local output="$1"
    local expected_keywords="$2"  # comma-separated

    local score=0
    local total=0

    IFS=',' read -ra KEYWORDS <<< "$expected_keywords"
    for kw in "${KEYWORDS[@]}"; do
        ((total++))
        if echo "$output" | grep -qi "$kw"; then
            ((score++))
        fi
    done

    # Normalize to 0-5 scale
    if [[ $total -gt 0 ]]; then
        echo $(( (score * 5 + total - 1) / total ))
    else
        echo 0
    fi
}

# Print test summary
print_summary() {
    local test_name="$1"
    local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $test_name Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "  Total:   $total"
    echo -e "  ${GREEN}Passed:  $PASS_COUNT${NC}"
    echo -e "  ${RED}Failed:  $FAIL_COUNT${NC}"
    echo -e "  ${YELLOW}Skipped: $SKIP_COUNT${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Save result to file for cross-test comparison
save_result() {
    local test_id="$1"
    local group="$2"      # "pulz" or "baseline"
    local output="$3"

    local result_file="$RESULTS_DIR/${test_id}_${group}.txt"
    echo "$output" > "$result_file"
    echo "$result_file"
}
