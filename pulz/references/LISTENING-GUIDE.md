# Listening Guide (Wen-Zhen)

This reference provides the error pattern catalog and runtime signal
interpretation guide for Phase 2 of the Pulz diagnostic workflow.

## Error Message Analysis

### Stack Trace Reading

1. Start from the **bottom** of the stack trace (most recent call).
2. Identify the **first frame in user code** (skip framework/library frames).
3. Note the exception type and message.
4. Look for **chained exceptions** (caused by / wrapped exceptions).
5. Compare against known error patterns below.

### Common Error Type Classification

| Error Category       | Indicators                                           |
|----------------------|------------------------------------------------------|
| Null Reference       | NullPointerException, TypeError: cannot read property of null/undefined |
| Index Out of Bounds  | IndexError, ArrayIndexOutOfBoundsException            |
| Type Mismatch        | TypeError, ClassCastException, invalid conversion     |
| Concurrency          | Deadlock detection, race condition symptoms, ConcurrentModificationException |
| Resource Exhaustion  | OutOfMemoryError, Too many open files, Connection pool exhausted |
| Timeout              | TimeoutException, context deadline exceeded           |
| Serialization        | JSON parse error, protobuf decode failure             |
| Permission           | PermissionError, AccessDeniedException                |

---

## Log Pattern Recognition

### Anomaly Patterns

- **Spike pattern**: sudden increase in error frequency at a specific timestamp.
  Correlate with deployments, config changes, or external service events.
- **Gradual degradation**: slowly increasing error rate or latency. Suggests
  resource leak or accumulation bug.
- **Periodic pattern**: errors occur at regular intervals. Check cron jobs,
  scheduled tasks, or cache expiration.
- **Correlated errors**: multiple different error types appearing together.
  Suggests a shared root cause upstream.

### Key Log Signals

| Signal                          | Possible Root Cause                       |
|---------------------------------|-------------------------------------------|
| Repeated retry attempts         | Transient failure or misconfigured retry  |
| "Connection refused" clusters   | Downstream service down or port mismatch  |
| Increasing response times       | Resource leak, N+1 query, lock contention |
| Alternating success/failure     | Race condition, flaky dependency          |
| Errors only at specific times   | Timezone bug, scheduled job conflict      |

---

## Runtime Resource Indicators

### Memory Leak Signals

- Heap usage grows monotonically without plateauing.
- Garbage collection frequency increases over time.
- OutOfMemoryError after extended runtime (not on startup).

### Connection/Handle Leak Signals

- "Too many open files" or "Connection pool exhausted" after sustained load.
- Connections in TIME_WAIT or CLOSE_WAIT state accumulating.
- File descriptor count growing over process lifetime.

### Deadlock Signals

- Thread dump shows threads waiting on each other's locks.
- Application hangs without CPU usage increase.
- Request timeout with no error log from the application itself.

---

## Listening Notes Template

```
### Listening Notes

**Error summary**:
- Error type: [classification]
- Error message: [exact message]
- Frequency: [count / time window]

**Log pattern**:
- Pattern type: [spike / gradual / periodic / correlated]
- Key signal: [description]

**Runtime indicators**:
- [indicator]: [observed value or trend]

**Preliminary hypothesis from listening**:
[What the runtime signals suggest about the bug]
```
