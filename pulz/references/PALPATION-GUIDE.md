# Palpation Guide (Qie-Zhen)

This reference provides dynamic debugging strategies, reproduction test
guidelines, and data flow tracing methods for Phase 4 of the Pulz diagnostic
workflow.

## Reproduction Test Writing

### Principles

1. **Test must fail first**: write the test, confirm it fails with the bug
   present, THEN write the fix.
2. **Minimal reproduction**: strip away all irrelevant setup. The test should
   contain only what is necessary to trigger the bug.
3. **Deterministic**: avoid flaky reproductions. If the bug is timing-dependent,
   use synchronization primitives or mocks to make it deterministic.
4. **Descriptive name**: the test name should describe the bug, not the fix.
   Example: `test_getUserProfile_throws_when_user_not_found` not
   `test_null_check_added`.

### Reproduction Test Template

```
# Language-agnostic pseudocode structure

test "[descriptive bug scenario name]":
    # Arrange: set up the minimal state that triggers the bug
    setup = create_minimal_context()

    # Act: execute the code path that exhibits the bug
    result = execute_buggy_path(setup)

    # Assert: verify the bug's manifestation
    assert result matches expected_buggy_behavior
    # After fix, this assertion should be updated to:
    # assert result matches expected_correct_behavior
```

---

## Dynamic Debugging Strategies

### Breakpoint Strategy

1. **Start at the crash site**: set the first breakpoint at the line indicated
   by the error/stack trace.
2. **Walk upstream**: move breakpoints to callers to find where the invalid
   state originates.
3. **Binary search**: for bugs without clear crash sites, place breakpoints at
   the midpoint of the suspect code path and narrow down.

### Variable State Inspection

At each breakpoint, check:

- Are all variables initialized and non-null?
- Do collection sizes match expectations?
- Are numeric values within expected ranges?
- Do string values match expected formats?
- Are boolean flags in expected states?

### Common Dynamic Debugging Patterns

| Bug Type              | Debugging Approach                                      |
|-----------------------|---------------------------------------------------------|
| Null reference        | Trace the null value upstream to its origin              |
| Off-by-one            | Log loop counter and collection size at each iteration   |
| Race condition        | Add logging with timestamps and thread/coroutine IDs    |
| Infinite loop         | Add iteration counter with forced break at threshold    |
| State corruption      | Log state transitions, find the unexpected mutation      |
| Memory leak           | Take heap snapshots at intervals, diff object counts    |

---

## Data Flow Tracing

### Forward Tracing

Start from the input and trace how data transforms through the code:

1. Identify the entry point (API handler, event listener, main function).
2. Follow the data through each transformation step.
3. At each step, verify the data's type, shape, and value range.
4. Mark the first point where the data diverges from expectations.

### Backward Tracing

Start from the bug's manifestation and trace back to the input:

1. Identify the exact expression that produces the wrong result.
2. Examine each sub-expression and operand.
3. Follow the origin of each incorrect value upstream.
4. Repeat until reaching external input or the point of corruption.

### Call Chain Analysis

For complex bugs involving multiple function calls:

1. List the complete call chain from entry point to bug site.
2. For each function in the chain, document:
   - Input parameters (expected vs. actual).
   - Return value (expected vs. actual).
   - Side effects (state mutations, I/O).
3. Identify the function where expected and actual behavior first diverge.

---

## Edge Case and Boundary Testing

After locating the bug, test these boundary conditions:

- **Empty/null inputs**: empty strings, empty collections, null values.
- **Boundary values**: 0, -1, MAX_INT, empty string vs. whitespace.
- **Single element**: collection with exactly one item.
- **Large inputs**: inputs at or beyond expected scale limits.
- **Concurrent access**: parallel calls to the same resource.
- **Error injection**: what happens when dependencies fail?

---

## Palpation Notes Template

```
### Palpation Notes

**Reproduction test**:
- Test name: [descriptive name]
- Test result: [FAIL -- confirms bug / PASS -- bug not reproduced]
- Minimal reproduction: [brief description of setup]

**Data flow trace**:
- Entry point: [function/endpoint]
- Divergence point: [where actual != expected]
- Invalid state: [what is wrong and what it should be]

**Root cause confirmation**:
- Hypothesis: [from previous phases]
- Confirmed: [yes/no -- evidence]

**Boundary conditions tested**:
- [condition]: [result]
```
