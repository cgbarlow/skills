# Agentic Coach

**An interactive prompt engineering coach that transforms vague prompts into precise, agentic specifications through guided dialogue and learning.**

## Overview

Agentic Coach is a Claude skill designed to help users craft better prompts through Socratic dialogue rather than automated transformation. Unlike tools that simply rewrite your prompts, this coach engages you in a conversation to understand your intent, teaches you principles along the way, and ensures you maintain full control over every decision.

The core philosophy: **you control everything**. The skill never auto-executes—it displays, asks, and waits for your explicit approval at every step.

## Key Features

- **Interactive Assessment** — Prompts are scored across six dimensions: clarity, structure, agentic readiness, completeness, executability, and learning value
- **Socratic Coaching** — Clarifying questions help surface your true intent before transformation
- **Multiple Transformation Styles** — Choose from quick fixes, full agentic architectures, learning mode comparisons, domain-specific tailoring, or iterative refinement
- **Built-in Teaching** — Every transformation includes explanations of the principles applied and patterns you can reuse
- **Full User Control** — Execute, modify, regenerate, or save—nothing happens without your say-so

## Transformation Styles

| Style | Best For |
|-------|----------|
| **Quick Fix** | Nearly-good prompts needing polish |
| **Full Agentic** | Complex tasks requiring multi-agent orchestration |
| **Learning Mode** | Understanding principles through side-by-side comparisons |
| **Domain-Specific** | Workflows tailored to your tech stack or industry |
| **Iterative** | Unclear requirements that need multiple refinement rounds |

## How It Works

1. **Provide your prompt** — Start with whatever you have, even something as vague as "I want to build an AI thing"
2. **Review the assessment** — See how your prompt scores across key dimensions
3. **Answer coaching questions** — Or skip with "just transform it" if you prefer
4. **Choose a transformation style** — Pick the approach that fits your needs
5. **Review and decide** — Execute, modify, regenerate, learn more, or save for later

## Shortcuts

| Command | Action |
|---------|--------|
| `just transform it` | Skip questions, get transformation immediately |
| `explain more` | Deeper teaching on any concept |
| `different style` | Try another transformation approach |
| `show options` | See multiple versions to compare |
| `new session` | Start fresh, clear context |

## Principles Taught

The coach introduces and reinforces core agentic engineering principles:

- **Agent Decomposition** — Breaking complex tasks into specialist agents (research, analysis, implementation, validation)
- **Success Metrics** — Defining quantitative targets and completion conditions
- **Iteration Strategy** — Building in feedback loops and validation checkpoints
- **Data Triangulation** — Cross-referencing multiple sources and perspectives
- **Testing Before Deployment** — Simulation, A/B comparisons, and canary deployments

## Anti-Patterns Identified

The coach flags common prompt issues:

- **One-Shot Wonder** — Assuming a single agent handles everything
- **Vague Vision** — Abstract goals without measurable outcomes
- **No Validation** — Building without testing phases
- **Resource Ignorance** — Ignoring constraints and limitations
- **Maintenance Blindness** — Forgetting post-launch needs

## Example

**Input:** "make my code faster"

**Full Agentic Output:**
```
Deploy performance optimization swarm:
- Profiling Agent: Identify bottlenecks with metrics
- Research Agent: Find SOTA optimization techniques
- Implementation Agent: Apply top 3 optimizations
- Validation Agent: Benchmark before/after

Success criteria: 30% latency reduction, p95 < 200ms
Iterate until benchmarks pass with statistical significance.
```

## Installation

Place the `SKILL.md` file in your Claude skills directory:
```
/mnt/skills/user/agentic-coach/SKILL.md
```

## Usage

Simply ask Claude to help you improve a prompt, or reference the skill directly. The coach will engage automatically when prompt improvement is requested.

## License

MIT

---

*Built for the [Agentics Foundation](https://agentics.org) community.*