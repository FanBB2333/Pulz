# Pulz Evaluation Suite

Validates that the Pulz skill (TCM-inspired debugging) improves Claude's debugging capabilities compared to baseline (no skill loaded).

## Evaluation Dimensions

| Layer | What it tests | Script |
|-------|---------------|--------|
| A. Trigger Accuracy | Skill activates on correct prompts, stays silent otherwise | `run-trigger-test.sh` |
| B. Diagnostic Quality | With-skill produces concrete diagnostic evidence, not just template output | `run-quality-test.sh` |
| C. Fix Correctness | With-skill finds and fixes bugs more accurately | `run-fix-test.sh` |

## Methodology

**A/B comparison**: Each bug scenario is run twice -- once with Pulz loaded (treatment group) and once without (control group). Outputs are scored on multiple dimensions.

This is NOT a benchmark against other tools. The goal is to prove **Pulz improves the same model's debugging performance**.

## Quick Start

```bash
# Run all tests
./run-all.sh

# Run individual layers
./run-trigger-test.sh
./run-quality-test.sh
./run-fix-test.sh
```

## Requirements

- Claude CLI (`claude`) installed and authenticated
- `jq` for JSON parsing
- Bash 4+

## Directory Structure

```
evals/
  trigger-prompts/         # Prompt classification test cases
    should-trigger.txt     # Prompts that should activate Pulz
    should-not-trigger.txt # Prompts that should NOT activate Pulz
  bug-scenarios/           # Self-contained buggy code + expected fixes
    01-null-deref/
    02-off-by-one/
    03-resource-leak/
    04-race-condition/
    05-type-coercion/
  fixtures/                # Buggy source files used by scenarios
  test-helpers.sh          # Shared assertion functions
  scoring.sh               # Output scoring functions
  run-trigger-test.sh      # Layer A
  run-quality-test.sh      # Layer B
  run-fix-test.sh          # Layer C
  run-all.sh               # Run everything
```
