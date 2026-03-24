#!/usr/bin/env bash
# Layer A: Trigger Accuracy Test
# Validates that Pulz activates on debugging prompts and stays silent on unrelated ones.

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$EVALS_DIR/test-helpers.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Layer A: Trigger Accuracy Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# --- Positive tests: should trigger ---
echo -e "${YELLOW}[Positive Cases] Prompts that SHOULD trigger Pulz${NC}"

while IFS= read -r prompt; do
    [[ -z "$prompt" || "$prompt" == \#* ]] && continue

    echo -e "\n  Testing: ${prompt:0:60}..."
    output=$(run_with_pulz "$prompt" "" 90)
    text=$(extract_text "$output")
    assert_skill_triggered "Trigger on: ${prompt:0:40}" "$text" || true

done < "$EVALS_DIR/trigger-prompts/should-trigger.txt"

echo ""

# --- Negative tests: should NOT trigger ---
echo -e "${YELLOW}[Negative Cases] Prompts that should NOT trigger Pulz${NC}"

while IFS= read -r prompt; do
    [[ -z "$prompt" || "$prompt" == \#* ]] && continue

    echo -e "\n  Testing: ${prompt:0:60}..."
    output=$(run_with_pulz "$prompt" "" 90)
    text=$(extract_text "$output")
    assert_skill_not_triggered "No trigger on: ${prompt:0:40}" "$text" || true

done < "$EVALS_DIR/trigger-prompts/should-not-trigger.txt"

echo ""
print_summary "Layer A: Trigger Accuracy"
