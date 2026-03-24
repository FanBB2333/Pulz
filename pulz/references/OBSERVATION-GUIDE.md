# Observation Guide (Wang-Zhen)

This reference provides the detailed checklist and pattern catalog for Phase 1
of the Pulz diagnostic workflow.

## Static Analysis Checklist

### Structural Complexity

- [ ] Function length: flag functions exceeding 50 lines (language-dependent).
- [ ] Cyclomatic complexity: flag functions with complexity > 10.
- [ ] Nesting depth: flag blocks nested > 4 levels deep.
- [ ] Parameter count: flag functions with > 5 parameters.
- [ ] Class size: flag classes with > 20 methods or > 500 lines.

### Dependency Health

- [ ] Circular dependencies between modules.
- [ ] Tight coupling: direct access to internal state across module boundaries.
- [ ] Missing dependency injection (hard-coded instantiation).
- [ ] Unused imports or dead code near the bug site.

### Type and Data Safety

- [ ] Unchecked null/undefined/nil access.
- [ ] Implicit type coercion in comparisons.
- [ ] Missing or overly broad type annotations.
- [ ] Unsafe type casting.
- [ ] Raw string manipulation where structured types exist.

### Resource Management

- [ ] File handles opened without corresponding close/cleanup.
- [ ] Database connections not returned to pool.
- [ ] Lock acquisition without guaranteed release.
- [ ] Event listeners registered without deregistration.

### Error Handling

- [ ] Empty catch/except blocks.
- [ ] Overly broad exception catching (catch-all).
- [ ] Missing error propagation (swallowed errors).
- [ ] Inconsistent error return conventions within the same module.

---

## Code Smell -- Bug Correlation Patterns

| Code Smell                | Commonly Associated Bug Types               |
|---------------------------|----------------------------------------------|
| Long method               | Logic errors, missed edge cases              |
| Deep nesting              | Off-by-one, wrong branch execution           |
| God class                 | State corruption, race conditions            |
| Feature envy              | Stale data, incorrect delegation             |
| Primitive obsession       | Validation bypass, type confusion            |
| Duplicate code            | Inconsistent fix propagation                 |
| Shotgun surgery pattern   | Incomplete refactor, partial updates         |
| Data clumps               | Missing abstraction, wrong field access      |

---

## Observation Notes Template

```
### Observation Notes

**Scope**: [files and functions examined]

**Structural findings**:
- [finding 1]
- [finding 2]

**Code smells identified**:
- [smell]: [location] -- [relevance to symptom]

**Preliminary hypothesis from observation**:
[What the code structure suggests about the bug]
```
