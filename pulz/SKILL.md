---
name: pulz
description: >-
  Diagnose and fix code bugs using Traditional Chinese Medicine (TCM) diagnostic
  methodology (Observation, Listening, Inquiry, Palpation). Use when the user
  mentions debugging, bug fixing, error diagnosis, code repair, or when a test
  failure or runtime error needs root cause analysis. Guides the agent through
  a structured four-phase diagnostic process before proposing minimal-invasive
  fixes.
license: MIT
metadata:
  author: FanBB2333
  version: "0.1.0"
---

# Pulz -- TCM-Inspired Code Diagnosis and Bug Fixing

## Overview

Pulz maps the Traditional Chinese Medicine (TCM) diagnostic framework onto the
software debugging process. Instead of jumping to a fix, the agent must first
complete a structured "four diagnosis" (si-zhen) examination to fully understand
the bug before prescribing a "treatment" (fix).

The core philosophy: **treat the root cause, not the symptom** (zhi-ben, not
zhi-biao).

## Core Workflow

Follow these phases **in order**. Do NOT skip ahead to treatment.

### Phase 1 -- Observation (Wang-Zhen)

Examine the code's visible structure without running it.

1. Identify the scope: which files, functions, and classes are involved.
2. Assess structural health:
   - Function/method length and cyclomatic complexity.
   - Nesting depth (loops, conditionals).
   - Dependency coupling between modules.
3. Look for "code smells" that correlate with the reported symptom:
   - Type mismatches, unchecked null/undefined, off-by-one patterns.
   - Resource acquisition without release (files, connections, locks).
   - Inconsistent error handling paths.
4. Record findings as **Observation Notes**.

See [OBSERVATION-GUIDE.md](references/OBSERVATION-GUIDE.md) for the full
checklist and pattern catalog.

### Phase 2 -- Listening (Wen-Zhen)

Analyze the runtime signals the code emits.

1. Read error messages, stack traces, and log output related to the bug.
2. Identify anomalous patterns:
   - Repeated error clusters.
   - Performance degradation trends.
   - Memory or resource leak indicators.
3. Classify the error type (logic error, runtime exception, concurrency issue,
   data corruption, etc.).
4. Record findings as **Listening Notes**.

See [LISTENING-GUIDE.md](references/LISTENING-GUIDE.md) for the error pattern
catalog.

### Phase 3 -- Inquiry (Wen-Zhen / Inquiry)

Collect context that cannot be observed from code or logs alone.

1. Ask the user (or infer from context):
   - When did the bug first appear? What changed recently?
   - Under what conditions does it reproduce? (environment, input, timing)
   - Is it consistent or intermittent?
2. Gather environmental context:
   - Language/runtime version, framework version, OS.
   - Relevant configuration and feature flags.
   - Recent commits or dependency updates.
3. Record findings as **Inquiry Notes**.

See [INQUIRY-GUIDE.md](references/INQUIRY-GUIDE.md) for the structured
question templates.

### Phase 4 -- Palpation (Qie-Zhen)

Probe the code dynamically to confirm the root cause.

1. **Write a reproduction test** that demonstrates the bug.
   - The test must fail before the fix and pass after.
2. Trace the data flow through the suspect code path.
3. Verify variable states at critical points.
4. Confirm the root cause hypothesis formed during Phases 1-3.
5. Record findings as **Palpation Notes**.

See [PALPATION-GUIDE.md](references/PALPATION-GUIDE.md) for debugging
strategies and test-writing guidelines.

---

## Diagnosis (Bian-Zheng)

After completing all four phases, synthesize a **Bug Profile**:

| Field               | Content                                              |
|---------------------|------------------------------------------------------|
| Symptom             | What the user observes (the "biao")                  |
| Root Cause          | The underlying defect (the "ben")                    |
| Affected Scope      | Files, functions, and data paths involved             |
| Confidence          | High / Medium / Low                                  |
| Evidence            | Key findings from each phase supporting the diagnosis |

## Treatment (Shi-Zhi)

Generate a fix following these principles:

1. **Minimal invasive repair** (zhen-jiu style / "acupuncture fix"):
   - Prefer the smallest change that resolves the root cause.
   - Avoid large refactors unless the root cause demands it.
2. **Reproduction test first**: the reproduction test from Phase 4 must exist
   and fail before applying the fix.
3. **Fix the root cause, not the symptom**: if the symptom is a crash but the
   root cause is a missing validation, fix the validation.
4. **Regression safety**: identify related code paths that could be affected
   and suggest additional test cases if needed.

## Output Format

Use the template in [diagnosis-report-template.md](assets/diagnosis-report-template.md)
to structure the final output. The report must include:

1. Four-phase findings summary (Observation / Listening / Inquiry / Palpation).
2. Bug Profile table.
3. Proposed fix with code diff.
4. Reproduction test code.
5. Prognosis: risk assessment and regression test suggestions.

## Execution Rules

- Complete all four diagnostic phases before proposing any fix.
- Always write a reproduction test before writing fix code.
- Do not use emoji in any output.
- Use precise technical language; avoid vague descriptions like "something is
  wrong".
- When information is unavailable for a phase, explicitly state what is missing
  and what assumptions are being made.
- Prefer root cause fixes over symptom patches. If only a symptom patch is
  feasible, document the technical debt.
- Structure all output using the diagnosis report template.

## Examples

### Example: NullPointerException in User Service

**Symptom**: `NullPointerException` at `UserService.java:42` when fetching user
profile.

**Observation**: `getUserProfile()` calls `repository.findById()` and directly
accesses `.getName()` without null check. The method has no input validation.

**Listening**: Stack trace shows the NPE occurs only for user IDs not in the
database. Logs show 12 occurrences in the last hour, all with non-existent IDs.

**Inquiry**: The bug appeared after a frontend change that stopped validating
user IDs before API calls. No backend changes in the last 2 weeks.

**Palpation**: Reproduction test confirms `getUserProfile(-1)` triggers the NPE.
`repository.findById(-1)` returns `null` as expected.

**Diagnosis**: Root cause is missing null-safety after `findById()`. The "biao"
is the NPE; the "ben" is absent defensive handling for non-existent entities.

**Treatment**: Add `Optional` handling for `findById()` return value; throw a
domain-specific `UserNotFoundException`. Reproduction test updated to assert the
correct exception type.
