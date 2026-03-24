# Diagnosis Report Template

Use this template to structure the output of a Pulz diagnostic session.

---

## Bug Diagnosis Report

### 1. Patient Information

| Field          | Value                          |
|----------------|--------------------------------|
| Project        | [project name]                 |
| File(s)        | [affected files]               |
| Reported By    | [user / test suite / monitor]  |
| Date           | [diagnosis date]               |

---

### 2. Chief Complaint (Symptom)

[Describe the observed symptom in the user's own words or as reported by the
test/monitoring system.]

---

### 3. Four Diagnosis Findings

#### 3.1 Observation (Wang-Zhen)

- **Structural findings**: [code complexity, dependency issues, code smells]
- **Key observations**: [specific patterns found in static analysis]

#### 3.2 Listening (Wen-Zhen)

- **Error signals**: [error type, frequency, pattern]
- **Runtime indicators**: [performance, resource usage trends]

#### 3.3 Inquiry (Wen-Zhen / Inquiry)

- **Context gathered**: [environment, recent changes, reproduction conditions]
- **Key information**: [critical context that informs the diagnosis]

#### 3.4 Palpation (Qie-Zhen)

- **Reproduction test**: [test name and result]
- **Data flow findings**: [where the data diverges from expectations]
- **Root cause confirmed**: [yes/no]

---

### 4. Bug Profile (Bian-Zheng)

| Field               | Content                                   |
|---------------------|-------------------------------------------|
| Symptom (Biao)      | [what the user observes]                  |
| Root Cause (Ben)    | [the underlying defect]                   |
| Affected Scope      | [files, functions, data paths]            |
| Confidence          | [High / Medium / Low]                     |
| Evidence Summary    | [key evidence from each diagnostic phase] |

---

### 5. Treatment Plan (Shi-Zhi)

#### 5.1 Proposed Fix

[Description of the fix approach and rationale.]

```diff
- [old code]
+ [new code]
```

#### 5.2 Reproduction Test

```
[reproduction test code that fails before fix and passes after]
```

---

### 6. Prognosis

- **Fix risk**: [Low / Medium / High -- explain why]
- **Regression areas**: [related code paths that should be re-tested]
- **Recommended follow-up tests**: [additional test cases to add]
- **Technical debt**: [any remaining issues not addressed by this fix]
