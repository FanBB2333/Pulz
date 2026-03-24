#!/usr/bin/env bash
# Layer B: Diagnostic Quality Test
# Checks that with-Pulz responses include concrete diagnostic evidence rather than
# only templated phase headings.

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

    # Check for evidence across the main diagnostic dimensions.
    echo "  Checking diagnostic evidence:"
    assert_contains "Static code reasoning" "$pulz_text" "line [0-9]\|function\|method\|class\|code.*path\|control.*flow\|branch\|index\|null\|undefined\|type\|resource\|lock" || true
    assert_contains "Runtime symptom analysis" "$pulz_text" "error\|exception\|stack.*trace\|runtime\|crash\|wrong result\|expected.*actual\|actual.*expected\|intermittent" || true
    assert_contains "Reproduction context" "$pulz_text" "reproduc\|input\|condition\|environment\|recent.*change\|thread\|batch\|context" || true
    assert_contains "Verification plan" "$pulz_text" "test\|assert\|verify\|fail.*before\|pass.*after\|trace\|confirm" || true

    # Check structured diagnosis output
    assert_contains "Root-cause synthesis" "$pulz_text" "root.*cause\|because\|due to\|caused by\|instead of\|rather than" || true
    assert_contains "Concrete fix plan" "$pulz_text" "fix\|repair\|patch\|solution\|change\|guard\|lock\|parse" || true

    # Check for structured report format (table, sections, etc.)
    struct_score=$(score_diagnostic_structure "$pulz_text")
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
