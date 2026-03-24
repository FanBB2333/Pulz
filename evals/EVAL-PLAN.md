# Pulz Skill Evaluation Plan

## Goal

Prove that loading the Pulz skill **improves Claude's debugging performance** compared to the same model without the skill. This is a self-comparison (A/B test), not a cross-tool benchmark.

---

## Evaluation Design

### Control vs Treatment

| Group | Configuration | Purpose |
|-------|---------------|---------|
| **Treatment** (Pulz) | `claude --skill-dir pulz/` | Agent with TCM diagnostic framework loaded |
| **Control** (Baseline) | `claude` (no skill) | Same model, same prompt, no skill guidance |

Both groups receive identical prompts, identical buggy code files, and identical timeout settings. The only variable is whether the Pulz skill is loaded.

### Why Self-Comparison?

External benchmarks (e.g., SWE-bench) test general coding ability across many tasks. Our goal is narrower: does the Pulz skill's structured diagnostic methodology produce **better debugging outcomes** than the model's default behavior? Self-comparison isolates this variable cleanly.

---

## Three Test Layers

### Layer A: Trigger Accuracy

**Question**: Does the skill activate when it should, and stay silent when it shouldn't?

**Method**:
- Feed 15 positive prompts (debugging/bug-fixing language) and 15 negative prompts (coding but non-debugging tasks) to Claude with Pulz loaded.
- Check output for skill activation indicators (TCM terminology, four-phase structure, diagnostic report).

**Metrics**:
- **Precision**: % of triggered responses that were on actual debugging prompts
- **Recall**: % of debugging prompts that successfully triggered the skill
- **Target**: Precision >= 80%, Recall >= 80%

**Script**: `run-trigger-test.sh`

---

### Layer B: Diagnostic Quality

**Question**: When triggered, does Pulz produce a structured, thorough diagnosis?

**Method**:
- Run all 5 bug scenarios with Pulz loaded.
- Check each output for concrete diagnostic evidence: code-path reasoning, runtime signals, reproduction context, verification steps, and root-cause synthesis.
- Score the diagnostic evidence on a 0-5 scale.

**Scoring Rubric** (per scenario, 0-5):

| Points | Criteria |
|--------|----------|
| +1 | Includes static reasoning tied to the buggy code path |
| +1 | Explains the observed runtime symptom or failure signal |
| +1 | Mentions reproduction conditions, input, or missing context |
| +1 | Proposes verification such as a repro test or dynamic trace |
| +1 | Synthesizes a root cause instead of only restating the symptom |

**Target**: Average score >= 3/5 across all scenarios

**Script**: `run-quality-test.sh`

---

### Layer C: Fix Correctness (A/B Test)

**Question**: Does Pulz help Claude find and fix bugs more accurately than baseline?

**Method**:
- Run each of the 5 bug scenarios twice: once with Pulz (treatment), once without (control).
- Score both outputs on three dimensions.
- Aggregate and compare.

**Scoring Dimensions** (per scenario):

#### Dimension 1: Thoroughness (0-10)
How systematically does the response analyze the problem before proposing a fix?

| Sub-dimension | Points | Criteria |
|---------------|--------|----------|
| Phase coverage | 0-4 | Covers structural, runtime, contextual, and dynamic analysis angles |
| Evidence gathering | 0-3 | Cites specific lines, explains causation, traces data flow |
| Structured output | 0-3 | Distinguishes root cause from symptom, identifies scope and impact |

#### Dimension 2: Root Cause Accuracy (0-5)
Does the response identify the correct root cause? Scored against normalized term coverage from `expected_root_cause`, so each scenario is scaled relative to its own reference explanation.

#### Dimension 3: Fix Completeness (0-5)
| Points | Criteria |
|--------|----------|
| +1 | Provides a concrete code fix (not just description) |
| +1 | Fix targets root cause, not just symptom |
| +1 | Includes or mentions reproduction test |
| +1 | Considers regression / side effects |
| +1 | Finds secondary bug (if scenario has one; auto-awarded if not) |

**Aggregate**: Each scenario yields a score out of 20 for both Pulz and baseline. Final comparison is the sum across all 5 scenarios (out of 100).

**Success Criteria**: Pulz aggregate score > Baseline aggregate score

**Script**: `run-fix-test.sh`

---

## Bug Scenarios

| ID | Bug Type | Language | Key Challenge |
|----|----------|----------|---------------|
| 01 | Null dereference | Python | Identify missing null check + find same pattern in sibling method |
| 02 | Off-by-one | JavaScript | Recognize 1-based vs 0-based index mismatch |
| 03 | Resource leak | Python | Trace connection lifecycle through pool acquire/release |
| 04 | Race condition | Python | Identify non-atomic read-modify-write in concurrent code |
| 05 | Type coercion | JavaScript | Trace string-typed input through arithmetic operations |

These cover a range of bug categories, languages, and complexity levels. Scenarios 01 and 05 include secondary bugs to test diagnostic thoroughness.

---

## Expected Pulz Advantages

The Pulz skill should outperform baseline specifically because it:

1. **Forces systematic diagnosis before fixing** -- baseline Claude often jumps straight to a fix, potentially missing the root cause or related issues.
2. **Provides a four-phase framework** -- ensures the agent examines the problem from multiple angles (static structure, runtime signals, context, dynamic verification).
3. **Requires reproduction tests** -- the palpation phase demands a test that fails before the fix, ensuring the fix is validated.
4. **Distinguishes root cause from symptom** -- the "zhi-ben not zhi-biao" principle should lead to more fundamental fixes.
5. **Finds related bugs** -- the observation phase's code smell checklist should catch patterns like "same null-deref in sibling method".

---

## Running the Tests

```bash
# Full suite (all three layers)
cd evals/
./run-all.sh

# Individual layers
./run-trigger-test.sh    # ~15 min (30 Claude calls)
./run-quality-test.sh    # ~10 min (5 Claude calls)
./run-fix-test.sh        # ~20 min (10 Claude calls)
```

Results are saved to `evals/results/` with timestamps for historical comparison.

---

## Statistical Considerations

- **Sample size**: 5 bug scenarios is small. Results should be interpreted as directional evidence, not statistically significant proof. To strengthen claims, expand to 15-20 scenarios.
- **Variance**: LLM outputs are non-deterministic. For robust results, run each scenario 3-5 times and report mean +/- std.
- **Keyword matching limitations**: Automated scoring via keyword matching is approximate. For publication-quality results, supplement with human evaluation or LLM-as-judge scoring.

### Extending to Multiple Runs

To run each scenario N times for statistical rigor:

```bash
# Example: 3 runs per scenario
for run in 1 2 3; do
    echo "=== Run $run ==="
    ./run-fix-test.sh
    mv results/ "results_run${run}/"
done
```

Then aggregate scores across runs to compute mean and standard deviation.

---

## Future Improvements

1. **LLM-as-judge**: Use a separate Claude call to score output quality on a rubric, reducing keyword-matching brittleness.
2. **Execution-based verification**: Actually run the proposed fix and check if the test passes.
3. **Larger scenario set**: Add concurrency bugs, memory leaks, API misuse, config errors, etc.
4. **Cross-language coverage**: Add Go, Java, Rust scenarios.
5. **Ablation study**: Test with individual phases removed to identify which diagnostic phase contributes most.
