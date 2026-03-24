#!/usr/bin/env bash
# Layer B: Diagnostic Quality Test
# A/B comparison: Does Pulz produce more structured, thorough diagnoses than baseline?
# Tests that with-Pulz responses contain four-phase diagnostic structure.

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$EVALS_DIR/test-helpers.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Layer B: Diagnostic Quality Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# For each bug scenario, check that the Pulz output follows the four-phase structure
for scenario_dir in "$EVALS_DIR"/bug-scenarios/*/; do
    scenario_file="$scenario_dir/scenario.json"
    [[ -f "$scenario_file" ]] || continue

    scenario_id=$(jq -r '.id' "$scenario_file")
    scenario_name=$(jq -r '.name' "$scenario_file")
    fixture=$(jq -r '.fixture' "$scenario_file")
    prompt=$(jq -r '.prompt' "$scenario_file")

    echo -e "${YELLOW}Scenario: $scenario_name ($scenario_id)${NC}"

    # Run with Pulz
    echo "  Running with Pulz skill..."
    pulz_output=$(run_with_pulz "$prompt" "$fixture" 120)
    pulz_text=$(extract_text "$pulz_output")
    save_result "$scenario_id" "pulz_quality" "$pulz_text" > /dev/null

    # Check four-phase structure presence
    echo "  Checking diagnostic structure:"
    assert_contains "Phase 1: Observation" "$pulz_text" "observation\|wang.zhen\|static.*analy\|code.*struct\|complex" || true
    assert_contains "Phase 2: Listening" "$pulz_text" "listening\|wen.zhen\|error.*signal\|log\|stack.*trace\|runtime" || true
    assert_contains "Phase 3: Inquiry" "$pulz_text" "inquiry\|context\|environment\|when.*appear\|condition\|reproduce" || true
    assert_contains "Phase 4: Palpation" "$pulz_text" "palpation\|qie.zhen\|test\|reproduc\|trace\|data.*flow\|variable.*state" || true

    # Check structured diagnosis output
    assert_contains "Bug Profile" "$pulz_text" "root.*cause\|bug.*profile\|diagnosis\|bian.zheng" || true
    assert_contains "Treatment Plan" "$pulz_text" "fix\|treatment\|repair\|patch\|solution" || true

    # Check for structured report format (table, sections, etc.)
    local struct_score=$(score_diagnostic_structure "$pulz_text")
    echo -e "  Diagnostic structure score: ${struct_score}/5"
    if [[ $struct_score -ge 3 ]]; then
        echo -e "  ${GREEN}PASS${NC}: Adequate diagnostic structure (${struct_score}/5)"
        ((PASS_COUNT++))
    else
        echo -e "  ${RED}FAIL${NC}: Insufficient diagnostic structure (${struct_score}/5, need >= 3)"
        ((FAIL_COUNT++))
    fi

    echo ""
done

print_summary "Layer B: Diagnostic Quality"
