#!/usr/bin/env bash
# Run all Pulz evaluation layers and generate a combined report.

set -euo pipefail

EVALS_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Pulz Skill Evaluation Suite          ║${NC}"
echo -e "${BLUE}║     TCM-Inspired Debugging Validation    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: 'claude' CLI not found. Install Claude Code first.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: 'jq' not found. Install with: brew install jq${NC}"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$EVALS_DIR/results/report_${TIMESTAMP}.txt"

echo "Results will be saved to: $REPORT_FILE"
echo ""

# Run each layer, capturing output
layer_a_exit=0
layer_b_exit=0
layer_c_exit=0

echo -e "${BLUE}[1/3] Running Layer A: Trigger Accuracy...${NC}"
bash "$EVALS_DIR/run-trigger-test.sh" 2>&1 | tee -a "$REPORT_FILE" || layer_a_exit=$?
echo ""

echo -e "${BLUE}[2/3] Running Layer B: Diagnostic Quality...${NC}"
bash "$EVALS_DIR/run-quality-test.sh" 2>&1 | tee -a "$REPORT_FILE" || layer_b_exit=$?
echo ""

echo -e "${BLUE}[3/3] Running Layer C: Fix Correctness A/B...${NC}"
bash "$EVALS_DIR/run-fix-test.sh" 2>&1 | tee -a "$REPORT_FILE" || layer_c_exit=$?
echo ""

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Combined Results                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

[[ $layer_a_exit -eq 0 ]] && a_status="${GREEN}PASS${NC}" || a_status="${RED}FAIL${NC}"
[[ $layer_b_exit -eq 0 ]] && b_status="${GREEN}PASS${NC}" || b_status="${RED}FAIL${NC}"
[[ $layer_c_exit -eq 0 ]] && c_status="${GREEN}PASS${NC}" || c_status="${RED}FAIL${NC}"

echo -e "  Layer A (Trigger Accuracy):    $a_status"
echo -e "  Layer B (Diagnostic Quality):  $b_status"
echo -e "  Layer C (Fix Correctness A/B): $c_status"
echo ""
echo "Full report saved to: $REPORT_FILE"

# Exit with failure if any layer failed
exit $((layer_a_exit + layer_b_exit + layer_c_exit))
