<div align="center">

# Pulz

> *"Feel the pulse of your code."*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

<br>

Bug reports that say "it doesn't work"?<br>
Stack traces longer than the code itself?<br>
Hotfixes that create two new bugs for every one they close?<br>
AI agents that jump to a patch without understanding the disease?<br>

**Stop treating symptoms. Diagnose the root cause.**

Pulz is an [Agent Skill](https://agentskills.io) that guides LLM / Coding Agents to diagnose and fix bugs<br>
using Traditional Chinese Medicine (TCM) diagnostic methodology — a structured four-phase examination<br>
before prescribing a minimal-invasive repair.

[How It Works](#how-it-works) · [Quick Start](#quick-start) · [Design Reference](#design-reference)

</div>

---

## How It Works

| Phase | TCM Concept | What the Agent Does |
|-------|-------------|---------------------|
| 1. Observation | Wang-Zhen | Static code analysis: structure, complexity, code smells |
| 2. Listening | Wen-Zhen | Runtime signal analysis: logs, errors, performance data |
| 3. Inquiry | Wen-Zhen (Inquiry) | Context collection: environment, recent changes, reproduction conditions |
| 4. Palpation | Qie-Zhen | Dynamic debugging: reproduction tests, data flow tracing |
| Diagnosis | Bian-Zheng | Synthesize findings into a Bug Profile |
| Treatment | Shi-Zhi | Generate minimal-invasive fix with reproduction test |

## Quick Start

### Use with any Agent Skills-compatible tool

Copy the `pulz/` directory into your project or agent's skill discovery path:

```
cp -r pulz/ /path/to/your/skills/
```

### Directory Structure

```
pulz/
  SKILL.md                               # Core skill instructions
  references/
    OBSERVATION-GUIDE.md                  # Phase 1: static analysis checklist
    LISTENING-GUIDE.md                    # Phase 2: error pattern catalog
    INQUIRY-GUIDE.md                      # Phase 3: question templates
    PALPATION-GUIDE.md                    # Phase 4: debugging strategies
  assets/
    diagnosis-report-template.md          # Structured output template
```

### Usage with Claude Code

Place the `pulz/` directory under `.claude/skills/` in your project root:

```
.claude/skills/pulz/SKILL.md
```

### Usage with other agents

Place the `pulz/` directory where your agent discovers skills. Refer to your
agent's documentation for the appropriate path.

## Design Reference

See [spec.md](spec.md) for the complete design specification, including
planned features beyond bug fixing (visualization, CI/CD integration,
adaptive learning, etc.).

---

<div align="center">

MIT License © [L1ght](https://github.com/FanBB2333)

</div>