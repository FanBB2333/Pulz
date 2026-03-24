#!/usr/bin/env bash
# Layer C: Fix Correctness A/B Test
# Core evaluation: compare Pulz vs baseline on the same bug scenarios.
# Measures: thoroughness, root cause accuracy, fix completeness.

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$EVALS_DIR/scoring.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Layer C: Fix Correctness A/B Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

PULZ_TOTAL=0
BASE_TOTAL=0
SCENARIO_COUNT=0

for scenario_dir in "$EVALS_DIR"/bug-scenarios/*/; do
    scenario_file="$scenario_dir/scenario.json"
    [[ -f "$scenario_file" ]] || continue

    scenario_id=$(jq -r '.id' "$scenario_file")
    scenario_name=$(jq -r '.name' "$scenario_file")
    fixture=$(jq -r '.fixture' "$scenario_file")
    prompt=$(jq -r '.prompt' "$scenario_file")
    expected_root_cause=$(jq -r '.expected_root_cause' "$scenario_file")
    has_secondary=$(jq -r '.has_secondary_bug' "$scenario_file")

    echo -e "${YELLOW}Scenario: $scenario_name${NC}"

    # --- Run WITH Pulz ---
    echo "  [1/2] Running WITH Pulz skill..."
    pulz_raw=$(run_with_pulz "$prompt" "$fixture" 120)
    pulz_text=$(extract_text "$pulz_raw")
    save_result "$scenario_id" "pulz_fix" "$pulz_text" > /dev/null

    # --- Run WITHOUT Pulz (baseline) ---
    echo "  [2/2] Running WITHOUT Pulz skill (baseline)..."
    base_raw=$(run_without_pulz "$prompt" "$fixture" 120)
    base_text=$(extract_text "$base_raw")
    save_result "$scenario_id" "baseline_fix" "$base_text" > /dev/null

    # --- Compare ---
    result=$(compare_ab "$scenario_id" "$pulz_text" "$base_text" "$expected_root_cause" "$has_secondary")

    # Parse last line for scores
    scores_line=$(echo "$result" | tail -1)
    pulz_score=$(echo "$scores_line" | cut -d: -f1)
    base_score=$(echo "$scores_line" | cut -d: -f2)

    # Print everything except the raw score line
    printf '%s\n' "$result" | sed '$d'

    PULZ_TOTAL=$((PULZ_TOTAL + pulz_score))
    BASE_TOTAL=$((BASE_TOTAL + base_score))
    ((SCENARIO_COUNT++))

    echo ""
done

# --- Final Summary ---
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Layer C: Overall A/B Results${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "  Scenarios tested: $SCENARIO_COUNT"
echo ""
printf "  %-20s %8s %8s\n" "" "Pulz" "Baseline"
printf "  %-20s %8s %8s\n" "--------------------" "--------" "--------"
printf "  %-20s %8d %8d\n" "Aggregate Score" "$PULZ_TOTAL" "$BASE_TOTAL"

if [[ $SCENARIO_COUNT -gt 0 ]]; then
    pulz_avg=$((PULZ_TOTAL * 100 / SCENARIO_COUNT / 20))
    base_avg=$((BASE_TOTAL * 100 / SCENARIO_COUNT / 20))
    printf "  %-20s %7d%% %7d%%\n" "Average (%)" "$pulz_avg" "$base_avg"
fi

echo ""
if [[ $PULZ_TOTAL -gt $BASE_TOTAL ]]; then
    improvement=$(( (PULZ_TOTAL - BASE_TOTAL) * 100 / (BASE_TOTAL > 0 ? BASE_TOTAL : 1) ))
    echo -e "  ${GREEN}RESULT: Pulz outperforms baseline by ${improvement}%${NC}"
    echo -e "  ${GREEN}        ($PULZ_TOTAL vs $BASE_TOTAL points across $SCENARIO_COUNT scenarios)${NC}"
elif [[ $PULZ_TOTAL -lt $BASE_TOTAL ]]; then
    echo -e "  ${RED}RESULT: Baseline outperforms Pulz${NC}"
    echo -e "  ${RED}        ($BASE_TOTAL vs $PULZ_TOTAL points across $SCENARIO_COUNT scenarios)${NC}"
else
    echo -e "  ${YELLOW}RESULT: Tie ($PULZ_TOTAL points each)${NC}"
fi
echo ""
