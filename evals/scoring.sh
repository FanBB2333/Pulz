#!/usr/bin/env bash
# Scoring functions for A/B comparison between Pulz and baseline

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

# Extract salient tokens from an expected root-cause description.
extract_reference_terms() {
    local text="$1"

    printf '%s\n' "$text" |
        tr '[:upper:]' '[:lower:]' |
        sed -E 's/[^[:alnum:]_]+/ /g' |
        tr ' ' '\n' |
        awk '
            length($0) >= 3 &&
            $0 !~ /^(the|and|for|with|without|from|into|onto|that|this|those|these|then|than|when|while|after|before|does|doing|did|used|uses|using|through|their|there|where|which|because|cause|caused|causes|return|returns|read|reads|write|writes|allow|allows|allowing|caller|callers|but|are|not|non|user|users|id|ids|dict|key|keys|value|values|item|items|data|arrive|arrives|perform|performs)$/ &&
            !seen[$0]++
        '
}

# Dimension 1: Diagnostic Thoroughness (0-10)
# Does the response systematically analyze the problem before jumping to a fix?
score_thoroughness() {
    local output="$1"
    local score=0

    # Phase coverage (0-4): did the response cover all diagnostic angles?
    echo "$output" | grep -qi "line [0-9]\|function\|method\|class\|code.*path\|control.*flow\|branch\|index\|null\|undefined\|type\|resource\|lock" && ((score++)) || true
    echo "$output" | grep -qi "error\|exception\|stack.*trace\|runtime\|crash\|wrong result\|expected.*actual\|actual.*expected\|intermittent" && ((score++)) || true
    echo "$output" | grep -qi "context\|environment\|when\|condition\|reproduce\|recent.*change\|input\|thread\|batch" && ((score++)) || true
    echo "$output" | grep -qi "test\|assert\|verify\|fail.*before\|pass.*after\|trace.*flow\|variable\|state\|confirm" && ((score++)) || true

    # Evidence gathering (0-3): did it cite specific evidence?
    echo "$output" | grep -qi "line [0-9]\|function.*[[:alnum:]_]\|method.*[[:alnum:]_]\|class.*[[:alnum:]_]\|file\|module" && ((score++)) || true
    echo "$output" | grep -qi "because\|due to\|caused by\|the reason\|this happens" && ((score++)) || true
    echo "$output" | grep -qi "data.*flow\|call.*chain\|execution.*path\|control.*flow\|read.*modify.*write\|returned.*then" && ((score++)) || true

    # Structured output (0-3): is the analysis organized?
    echo "$output" | grep -qi "root.*cause\|underlying\|fundamental\|instead of\|rather than" && ((score++)) || true
    echo "$output" | grep -qi "symptom\|observed\|reported\|visible\|crash\|wrong result\|exception" && ((score++)) || true
    echo "$output" | grep -qi "scope\|affected\|impact\|related\|regress\|secondary\|other.*path\|another.*instance" && ((score++)) || true

    echo "$score"
}

# Dimension 2: Root Cause Accuracy (0-5)
# Did the response identify the correct root cause?
score_root_cause() {
    local output="$1"
    local expected_root_cause="$2"

    local score=0
    local matched=0
    local total=0
    local normalized_output

    normalized_output=$(printf '%s\n' "$output" | tr '[:upper:]' '[:lower:]')

    while IFS= read -r kw; do
        [[ -z "$kw" ]] && continue
        ((total++))
        if echo "$normalized_output" | grep -Fqi "$kw"; then
            ((matched++))
        fi
    done < <(extract_reference_terms "$expected_root_cause")

    if [[ $total -eq 0 ]]; then
        echo 0
        return
    fi

    local ratio=$((matched * 100 / total))

    # Scale against expected-term coverage so each scenario can reach 5/5.
    if [[ $ratio -ge 85 ]]; then score=5
    elif [[ $ratio -ge 65 ]]; then score=4
    elif [[ $ratio -ge 45 ]]; then score=3
    elif [[ $ratio -ge 25 ]]; then score=2
    elif [[ $ratio -ge 10 ]]; then score=1
    fi

    echo "$score"
}

# Dimension 3: Fix Completeness (0-5)
# Does the fix address the root cause and related issues?
score_fix_completeness() {
    local output="$1"
    local has_secondary="$2"  # "true" or "false"

    local score=0

    # Has a concrete fix (not just description)
    echo "$output" | grep -qi "diff\|patch\|replace\|change.*to\|fix.*by\|should be\|instead of" && ((score++)) || true

    # Fix targets root cause not symptom
    echo "$output" | grep -qi "root.*cause\|underlying\|instead of.*workaround\|not just\|fundamental" && ((score++)) || true

    # Has reproduction test
    echo "$output" | grep -qi "test\|assert\|expect\|should.*fail\|should.*pass\|verify" && ((score++)) || true

    # Mentions regression / side effects
    echo "$output" | grep -qi "regress\|side.effect\|also.*affect\|other.*place\|related.*code" && ((score++)) || true

    # Found secondary bug (bonus for scenarios that have one)
    if [[ "$has_secondary" == "true" ]]; then
        echo "$output" | grep -qi "also\|similar.*pattern\|same.*issue\|another.*instance\|get_user_email\|quantity.*string" && ((score++)) || true
    else
        ((score++))  # Auto-award if no secondary bug to find
    fi

    echo "$score"
}

# Compare A/B results and generate report
compare_ab() {
    local scenario_id="$1"
    local pulz_output="$2"
    local baseline_output="$3"
    local expected_root_cause_text="$4"
    local has_secondary="$5"

    echo ""
    echo -e "${BLUE}--- Scenario: $scenario_id ---${NC}"

    # Score both
    local pulz_thorough=$(score_thoroughness "$pulz_output")
    local base_thorough=$(score_thoroughness "$baseline_output")

    local pulz_root=$(score_root_cause "$pulz_output" "$expected_root_cause_text")
    local base_root=$(score_root_cause "$baseline_output" "$expected_root_cause_text")

    local pulz_fix=$(score_fix_completeness "$pulz_output" "$has_secondary")
    local base_fix=$(score_fix_completeness "$baseline_output" "$has_secondary")

    local pulz_total=$((pulz_thorough + pulz_root + pulz_fix))
    local base_total=$((base_thorough + base_root + base_fix))

    # Report
    printf "  %-25s %8s %8s\n" "Dimension" "Pulz" "Baseline"
    printf "  %-25s %8s %8s\n" "-------------------------" "--------" "--------"
    printf "  %-25s %5d/10 %5d/10\n" "Thoroughness" "$pulz_thorough" "$base_thorough"
    printf "  %-25s %6d/5 %6d/5\n" "Root Cause Accuracy" "$pulz_root" "$base_root"
    printf "  %-25s %6d/5 %6d/5\n" "Fix Completeness" "$pulz_fix" "$base_fix"
    printf "  %-25s %5d/20 %5d/20\n" "TOTAL" "$pulz_total" "$base_total"
    echo ""

    if [[ $pulz_total -gt $base_total ]]; then
        echo -e "  ${GREEN}Result: Pulz wins (+$((pulz_total - base_total)))${NC}"
    elif [[ $pulz_total -lt $base_total ]]; then
        echo -e "  ${RED}Result: Baseline wins (+$((base_total - pulz_total)))${NC}"
    else
        echo -e "  ${YELLOW}Result: Tie${NC}"
    fi

    # Return scores as "pulz_total:base_total" for aggregation
    echo "$pulz_total:$base_total"
}
