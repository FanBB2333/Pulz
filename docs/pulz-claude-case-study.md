# Pulz Case Study: Claude Baseline vs Pulz-Augmented Prompt

Date: 2026-03-25

## Goal

Check a few simple bug-fix case studies to see what changes when Claude is run:

- without Pulz guidance
- with Pulz guidance available to Claude

This is a lightweight case study, not a formal benchmark.

## Setup

Claude Code natively supports `--add-dir` for mounting an extra workspace into the current session context:

```bash
claude -p \
  --output-format json \
  --permission-mode bypassPermissions \
  --model sonnet \
  --max-turns 3 \
  --add-dir /path/to/your/custom/workspace \
  "$PROMPT"
```

In practice, this can be used to expose an external skill workspace to Claude so the session can discover and load the skills under that directory.

For the already captured outputs in this document, the treatment side used a compatibility approximation by injecting `pulz/SKILL.md` through `--append-system-prompt`. For future reruns of this case study, the preferred native treatment path is:

```bash
claude -p \
  --output-format json \
  --permission-mode bypassPermissions \
  --model sonnet \
  --max-turns 3 \
  --add-dir /Users/l1ght/repos/Pulz/pulz \
  "$PROMPT"
```

The baseline side used the same command without Pulz-specific context.

All prompts were intentionally simple: "Help me debug and fix this bug", followed by the symptom and a small standalone code snippet.

## Versions

- `Pulz` skill version: `0.1.0` from [pulz/SKILL.md](/Users/l1ght/repos/Pulz/pulz/SKILL.md)
- `Claude Code` version used for these runs: `2.1.74`

## Cases

1. `null_deref`: Python null dereference in `UserService`
2. `off_by_one`: JavaScript pagination offset bug
3. `resource_leak`: Python connection pool leak

## Heuristic Summary

Scores below are from the current local eval heuristics. They are useful as a rough directional signal, but should not be treated as ground truth.

| Case | Mode | Words | Diagnostic | Thoroughness | Root Cause | Fix Completeness | Total |
|------|------|------:|-----------:|-------------:|-----------:|-----------------:|------:|
| `null_deref` | Baseline | 119 | 3 | 7 | 3 | 4 | 17 |
| `null_deref` | Pulz | 476 | 5 | 8 | 3 | 5 | 21 |
| `off_by_one` | Baseline | 63 | 3 | 3 | 3 | 2 | 11 |
| `off_by_one` | Pulz | 465 | 5 | 8 | 5 | 5 | 23 |
| `resource_leak` | Baseline | 60 | 2 | 2 | 3 | 2 | 9 |
| `resource_leak` | Pulz | 1217 | 5 | 9 | 5 | 5 | 24 |

## What Actually Changed

### 1. `null_deref`

Baseline was already competent. It immediately identified the missing `None` guard, fixed both call sites, and mentioned the nearby sibling bug in `get_user_email`.

Pulz changed the workflow more than the root answer:

- it explicitly separated symptom, root cause, scope, confidence, and evidence
- it added a reproduction test
- it proposed a domain exception plus a small helper method to remove duplication
- it added a short prognosis and regression note

Net effect: Pulz produced a more reviewable bug report and a more complete repair plan, but the baseline already found the core bug quickly.

Selected output excerpts:

Baseline:

```text
The bug is in `get_user_display_name` (and the same issue exists in `get_user_email`):
`find_by_id` returns `None` when the user isn't found, but both methods subscript
the result without checking first.
```

Pulz:

```text
## Diagnosis Report

### Phase 1 -- Observation (Wang-Zhen)
- `find_by_id` uses `dict.get(user_id)`, which returns `None` for missing keys
- `get_user_display_name` and `get_user_email` both subscript the result with no null guard
```

### 2. `off_by_one`

Baseline gave the minimal correct fix: change `page * pageSize` to `(page - 1) * pageSize`.

Pulz again expanded the process:

- it explained why the bug is a contract mismatch between 1-based page numbering and 0-based indexing
- it added explicit reproduction checks
- it verified the fix on page 1, 2, and 3
- it suggested a follow-up guard for invalid input such as `page < 1`

Net effect: this is the clearest example where Pulz improved the modification workflow for a simple bug. The final code change stayed minimal, but the validation and edge-case thinking got noticeably better.

Selected output excerpts:

Baseline:

```text
The bug is an off-by-one error. The start index uses `page * pageSize`, which
treats pages as 0-indexed.
```

Pulz:

```text
## Phase 3 -- Inquiry (Wen-Zhen / Inquiry)
- The caller uses 1-based page numbers
- The formula `page * pageSize` is correct for 0-based pages
- Mismatch between the external contract and the internal formula
```

### 3. `resource_leak`

This case is the most interesting one.

Baseline was short and correct:

- it identified that `release()` removes the connection from `_in_use` but never returns it to `_pool`
- it proposed the minimal patch: append the connection back to `_pool`

Pulz eventually identified the same real bug, but the response also showed a downside:

- it spent much more time in extended diagnosis
- it speculated about concurrency and TOCTOU behavior
- it ended up proposing a broader `Condition`-based redesign, not just the minimal pool fix

Net effect: Pulz made the process more thorough, but for this simple bug it also over-engineered the solution. The heuristic scorer marked Pulz as much better, but manual inspection says the baseline answer is actually preferable here because it is simpler and targets the real defect directly.

Selected output excerpts:

Baseline:

```text
The bug is in `release` — it removes the connection from `_in_use` but never
returns it to `_pool`.
```

Pulz:

```text
Pulz eventually proposes returning the connection to `_pool`, but it also expands
the design to a `Condition`-based acquire/release flow with waiting and notify.
```

## Practical Takeaways

- Pulz reliably changes Claude's workflow from "spot fix" to "diagnose, validate, then fix".
- On small logic bugs, the main gain is not raw correctness; it is better structure, explicit reproduction thinking, and regression awareness.
- On trivial bugs, baseline Claude is often already good enough and much shorter.
- On slightly tricky bugs, Pulz tends to surface better test ideas and scope analysis.
- Pulz can also over-shoot: for simple defects it may introduce unnecessary abstraction or broader refactors because the framework pushes it toward deeper diagnosis.

## Project Optimization Directions

One concrete optimization direction for Pulz is to introduce an explicit **repair escalation ladder** instead of always expanding into the deepest diagnostic form. A practical version would be:

- **Minimal-fix mode**: default for deterministic single-function bugs such as null checks, off-by-one errors, and simple return-value mistakes. Require root cause, patch, and one repro test, but avoid structural refactors.
- **Condition mode**: reserved for real coordination bugs such as blocked consumers, wake-up semantics, bounded-resource contention, or queue/pool scheduling issues. In this mode Pulz may recommend `Condition`, wait/notify, timeout handling, or stronger concurrency primitives, but only after evidence shows the problem is not just a missing release or missing state update.
- **Evidence gate before escalation**: before switching from minimal fix to Condition mode, require at least one concrete concurrency signal such as multi-thread contention, waiters that never wake, starvation, or a repro that still fails after the smallest state-management fix.
- **Dual output tiers**: keep both a short "patch-first" answer and a full "diagnosis report" answer, so simple bugs do not pay the full verbosity cost.

## Bottom Line

For simple case studies, loading Pulz does make a visible difference, but the difference is mostly in **workflow quality**, not always in **final patch correctness**.

The pattern from these three runs is:

- baseline: shorter, faster, often already correct
- Pulz: more structured, more test-oriented, more likely to mention scope and regression risk
- tradeoff: Pulz can over-analyze and occasionally recommend a bigger change than the bug really needs

So if the goal is "make the fix process more disciplined and auditable", Pulz helps.
If the goal is "get the shortest correct patch for a very small bug", baseline Claude may already be sufficient.
