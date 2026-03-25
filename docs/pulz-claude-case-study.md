# Pulz Case Study: Claude Baseline vs Pulz-Augmented Prompt

Date: 2026-03-25

## Goal

Measure whether adding `Pulz` actually improves bug-fix success rate under the
current local Claude Code configuration.

This document now contains two layers:

- a current **execution-based** measurement on 8 bug scenarios using the local
  `glm-4.7` configuration
- the earlier **qualitative** notes from a few simple examples, preserved for
  output-style comparison

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

For the quantified run in this document, I did **not** use `--add-dir` as the
formal treatment path. A smoke test on the current `glm-4.7` setup timed out
for more than 180 seconds on a single minimal case when `--add-dir
/Users/l1ght/repos/Pulz/pulz` was enabled, which would have mixed "skill
effectiveness" with "native skill mounting stability".

To keep the underlying model/config identical while making Pulz activation
deterministic, the measured treatment path injected `pulz/SKILL.md` via
`--append-system-prompt`. The current local Claude Code configuration still came
from the same local config files; only the presence or absence of Pulz guidance
changed.

The preferred native treatment path for future reruns is still:

```bash
claude -p \
  --output-format json \
  --permission-mode bypassPermissions \
  --model sonnet \
  --max-turns 3 \
  --add-dir /Users/l1ght/repos/Pulz/pulz \
  "$PROMPT"
```

The execution-based run itself was produced by:

```bash
python3 evals/run_case_study.py
```

That runner asks Claude to return the full corrected file for each fixture, then
executes a per-scenario validator. This is closer to a real "can it actually fix
the bug?" measurement than a template or keyword score.

## Versions

- `Pulz` skill version: `0.1.0` from [pulz/SKILL.md](/Users/l1ght/repos/Pulz/pulz/SKILL.md)
- `Claude Code` version used for these runs: `2.1.74`
- configured model in `~/.claude/settings.json`: `glm-4.7`

## Cases

Simple cases:

1. `null_deref`: Python null dereference in `UserService`
2. `off_by_one`: JavaScript pagination offset bug
3. `resource_leak`: Python connection pool leak
4. `race_condition`: Python unsynchronized counter increment
5. `type_coercion`: JavaScript numeric/string coercion bug

Harder cases:

6. `checkpoint_ordering`: checkpoint committed before handler success
7. `tenant_cache_leak`: multi-tenant cache key missing tenant scope
8. `deadlock_transfer`: opposing transfers deadlock on inconsistent lock order

## Quantitative Result (`glm-4.7`)

Primary result file:
[evals/results/case_study_glm47_20260325_143804.json](/Users/l1ght/repos/Pulz/evals/results/case_study_glm47_20260325_143804.json)

| Slice | Baseline | Pulz | Delta |
|------|---------:|-----:|------:|
| Overall (8 cases) | 7/8 = 87.5% | 7/8 = 87.5% | 0.0 pp |
| Simple cases (01-05) | 4/5 = 80.0% | 4/5 = 80.0% | 0.0 pp |
| Hard cases (06-08) | 3/3 = 100.0% | 3/3 = 100.0% | 0.0 pp |

Per-case outcome from the measured run:

| Case | Baseline | Pulz | Note |
|------|---------:|-----:|------|
| `01-null-deref` | pass | pass | both applied minimal `None` guard fix |
| `02-off_by_one` | pass | fail | Pulz-side failure was a transient structured-output miss |
| `03-resource_leak` | fail | pass | baseline-side failure was a transient structured-output miss |
| `04-race_condition` | pass | pass | both synchronized counter updates correctly |
| `05-type_coercion` | pass | pass | both fixed numeric conversion path |
| `06-checkpoint_ordering` | pass | pass | both found the commit-before-apply ordering bug |
| `07-tenant_cache_leak` | pass | pass | both fixed tenant scoping in cache key/invalidation |
| `08-deadlock_transfer` | pass | pass | both enforced stable lock ordering |

### Interpretation

Under the current `glm-4.7` Claude Code configuration, adding Pulz did **not**
increase the execution-based fix rate on this 8-case suite. The measured
headline number is flat: `87.5%` vs `87.5%`.

The two misses in the full run were not validator failures on the repaired code;
they were transient structured-output failures, one on each side. I spot-reran
those two exact prompts afterward, and both succeeded on rerun. That means the
directional conclusion is still the same: in this setup, Pulz did not show a
clear repair-rate advantage, and the observed noise was not biased in Pulz's
favor or against it.

### What Changed Anyway

Even though the fix rate stayed flat, Pulz still changed some responses at the
text level. Representative excerpts from the measured run:

Baseline on `checkpoint_ordering`:

```text
The bug is that the checkpoint is saved before the handler executes. When
evt-2 fails, its offset (2) is already committed. On retry, the condition
`event["offset"] <= last_offset` causes `evt-2` to be skipped entirely.
```

Pulz on `checkpoint_ordering`:

```text
**Root Cause:** The checkpoint offset is saved before `handler.apply()`
succeeds. When processing evt-2, `checkpoint.save(offset=2)` executes first,
then `handler.apply()` raises RuntimeError. On retry, `checkpoint.load()`
returns 2, so the retry loop skips evt-2.
```

The difference is real but modest: Pulz tends to make the explanation slightly
more explicit and stepwise, but in this `glm-4.7` configuration that did not
translate into a higher end-to-end repair rate.

## Earlier Qualitative Notes

The sections below are older qualitative notes from 3 simpler cases. They are
kept here because they preserve more of the original Claude output style, but
they should not be confused with the execution-based fix-rate measurement above.

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

For the current `glm-4.7` setup, the measured answer is straightforward:
loading Pulz changed some explanation style, but it did **not** produce a higher
execution-based bug-fix rate on this case-study suite.

The current quantitative result is:

- baseline: `7/8`
- Pulz: `7/8`
- hard cases: `3/3` on both sides

So, with this model/config pair, Pulz currently looks more like a
**process-shaping skill** than a **repair-rate boosting skill**. If the project
goal is to improve final fix rate, the next optimization work should focus on
when to stay minimal, when to escalate, and how to avoid paying verbosity cost
without gaining extra correctness.
