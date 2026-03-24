# Inquiry Guide (Wen-Zhen / Inquiry)

This reference provides structured question templates and context collection
checklists for Phase 3 of the Pulz diagnostic workflow.

## Structured Question Templates

### Symptom Characterization

Ask these questions to understand the bug's manifestation:

1. **What is the exact symptom?**
   - What error message, incorrect behavior, or unexpected result do you see?
   - What is the expected behavior?

2. **When did it first appear?**
   - After a specific deployment, code change, or dependency update?
   - Has it always existed but was only recently noticed?

3. **How reproducible is it?**
   - 100% consistent, or intermittent?
   - If intermittent, approximate frequency?

4. **What is the reproduction path?**
   - Exact steps to trigger the bug.
   - Minimum input/state required.

5. **What is the blast radius?**
   - Does it affect all users or a subset?
   - Does it affect all environments or specific ones (staging vs. production)?

### Environmental Context

Collect this information to narrow down environmental factors:

1. **Runtime environment**:
   - Language and runtime version.
   - OS and architecture.
   - Container/VM configuration (if applicable).

2. **Dependencies**:
   - Framework version.
   - Key library versions (especially recently updated ones).
   - External service versions (database, cache, message queue).

3. **Configuration**:
   - Relevant config values (feature flags, limits, timeouts).
   - Environment-specific overrides.
   - Recent config changes.

### Change History

Identify recent changes that may correlate:

1. **Recent code changes**:
   - Commits in the affected area within the last N days.
   - Refactors or migrations that touched related modules.

2. **Recent infrastructure changes**:
   - Dependency updates, OS patches, runtime upgrades.
   - Network or DNS changes.
   - Scaling events (new instances, load changes).

---

## User Description to Bug Type Mapping

Users often describe bugs in non-technical terms. Use this mapping to translate:

| User Description                          | Likely Bug Category                    |
|-------------------------------------------|----------------------------------------|
| "It's slow"                               | Performance (N+1, missing index, leak) |
| "It works sometimes"                      | Race condition, flaky dependency       |
| "It used to work"                         | Regression from recent change          |
| "It only happens in production"           | Environment-specific config, data volume |
| "It works on my machine"                  | Environment diff, dependency version   |
| "The data is wrong"                       | Logic error, data corruption           |
| "It crashes randomly"                     | Memory issue, unhandled edge case      |
| "It hangs / freezes"                      | Deadlock, infinite loop, blocking I/O  |
| "It gives the wrong error"               | Error handling logic, wrong catch path |

---

## Context Inference

When the user is unavailable or context must be inferred:

1. Check `git log` for recent changes in the affected files.
2. Read `package.json` / `requirements.txt` / `go.mod` etc. for dependency
   versions.
3. Check CI/CD pipeline output for recent test failures.
4. Read project README or configuration files for environment specifications.
5. Examine test fixtures for expected behavior documentation.

---

## Inquiry Notes Template

```
### Inquiry Notes

**Symptom characterization**:
- Exact symptom: [description]
- First appearance: [when / what changed]
- Reproducibility: [consistent / intermittent -- conditions]

**Environment**:
- Runtime: [language version, OS]
- Key dependencies: [framework, libraries]
- Configuration: [relevant values]

**Recent changes**:
- [change 1]: [date, author, scope]

**Preliminary hypothesis from inquiry**:
[What the context suggests about the bug]
```
