# Flow Coach

> Interactive claude-flow orchestration coach that guides you through multi-agent swarm configuration without auto-executing anything.

## Overview

Flow Coach is a Claude Code skill that helps you master **claude-flow** orchestration through guided coaching. Instead of automatically running commands, it analyzes your task, recommends optimal configurations, and always asks for your approval before executing.

## Key Principles

- **Never Auto-Executes** - All commands are displayed for review first
- **User Control at Every Step** - You decide what happens next
- **Teaching Built-In** - Learn claude-flow patterns as you go
- **Progressive Complexity** - Start simple, scale up as needed

## Installation

The skill is already installed at:
```
.claude/skills/flow-coach/SKILL.md
```

To use it, simply describe your task to Claude and it will activate automatically when claude-flow orchestration is relevant.

## Usage

### Basic Invocation

Just describe what you want to build:

```
"I want to build a REST API with authentication using claude-flow"
```

Flow Coach will:
1. Assess your task complexity
2. Recommend orchestration mode (Swarm vs Hive-Mind)
3. Suggest topology (Mesh, Hierarchical, Ring, Star)
4. Select appropriate agents
5. Configure memory system
6. Generate commands for your review
7. Ask what you want to do next

### Example Interaction

**You:** "Help me set up claude-flow for a complex e-commerce platform"

**Flow Coach Response:**
```
TASK ASSESSMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Complexity:     █████████░ High (multi-component)
Duration:       ████████░░ Long (days/weeks)
Coordination:   █████████░ High (shared state needed)
Memory Needs:   ██████████ Persistent (cross-session)
Performance:    ███████░░░ Moderate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommendation: HIVE-MIND with HIERARCHICAL topology
```

Then presents configuration options and waits for your decision.

## Coaching Phases

| Phase | What Happens |
|-------|--------------|
| **1. Assessment** | Scores task across 5 dimensions |
| **2. Mode Selection** | Swarm vs Hive-Mind recommendation |
| **3. Topology** | Mesh/Hierarchical/Ring/Star guidance |
| **4. Agents** | Selects from 64 specialized agents |
| **5. Memory** | AgentDB vs ReasoningBank configuration |
| **6. Commands** | Generates ready-to-run setup |
| **7. Decision** | Asks before any execution |

## Decision Options

At every decision point, you can choose:

| Option | Action |
|--------|--------|
| `[E]` Execute | Run the recommended commands |
| `[M]` Modify | Change configuration before running |
| `[A]` Add | Include additional agents or tools |
| `[R]` Remove | Simplify the setup |
| `[X]` Explain | Get detailed reasoning |
| `[S]` Save | Save config for later use |
| `[L]` Learn | Understand the patterns being applied |

## Quick Reference

### Orchestration Modes

| Mode | Best For | Command |
|------|----------|---------|
| **Swarm** | Quick tasks, single features | `npx claude-flow@alpha swarm "task" --claude` |
| **Hive-Mind** | Complex projects, persistence | `npx claude-flow@alpha hive-mind wizard` |

### Topologies

| Topology | Use When |
|----------|----------|
| **Mesh** | Agents need constant collaboration |
| **Hierarchical** | Clear task delegation structure |
| **Ring** | Work flows in sequential stages |
| **Star** | Need centralized coordination |

### Agent Categories

| Category | Agents | Purpose |
|----------|--------|---------|
| Core Development | 5 | researcher, coder, tester, reviewer, planner |
| Architecture | 6 | system-architect, backend-dev, api-docs, etc. |
| Swarm Coordination | 8 | coordinators, queen, workers, scouts |
| Consensus | 7 | byzantine, raft, gossip, quorum, crdt |
| GitHub | 13 | PR, issues, releases, workflows |
| Performance | 6 | analyzers, validators, benchmarkers |

### Memory Systems

| System | Performance | Best For |
|--------|-------------|----------|
| **AgentDB** | 96x-164x faster | Large knowledge bases, ML |
| **ReasoningBank** | 2-3ms latency | Simple persistence, offline |
| **Hybrid** | Both benefits | Complex projects |

## Shortcuts

Speed up coaching with these phrases:

| Phrase | Effect |
|--------|--------|
| "just recommend" | Skip questions, get best config |
| "explain more" | Deeper teaching on any topic |
| "simpler setup" | Minimal configuration |
| "full power" | Maximum agents and features |
| "compare options" | See alternatives side-by-side |

## Common Workflows

### Quick Feature Development
```bash
npx claude-flow@alpha swarm "implement user login" --claude
npx claude-flow@alpha swarm status
```

### Complex Project Setup
```bash
npx claude-flow@alpha hive-mind wizard
# or
npx claude-flow@alpha hive-mind spawn "build platform" \
  --topology hierarchical --max-agents 8 --claude
```

### Resume Previous Session
```bash
npx claude-flow@alpha hive-mind resume session-xxxxx
```

### Memory Operations
```bash
# Store
npx claude-flow@alpha memory store key "value" --namespace project

# Search
npx claude-flow@alpha memory vector-search "query" --k 10

# List
npx claude-flow@alpha memory list --namespace project
```

## MCP Tools Reference

### Core
```javascript
mcp__claude-flow__swarm_init       // Initialize swarm
mcp__claude-flow__agent_spawn      // Create agents
mcp__claude-flow__task_orchestrate // Distribute tasks
mcp__claude-flow__swarm_status     // Monitor progress
```

### Memory
```javascript
mcp__claude-flow__memory_usage     // Store/retrieve
mcp__claude-flow__memory_search    // Pattern search
```

### Neural
```javascript
mcp__claude-flow__neural_train     // Train patterns
mcp__claude-flow__neural_patterns  // Analyze cognition
```

## SPARC Integration

Flow Coach integrates with SPARC methodology:

| Phase | Command | Agent |
|-------|---------|-------|
| **S**pecification | `sparc run spec-pseudocode` | specification |
| **P**seudocode | `sparc run spec-pseudocode` | pseudocode |
| **A**rchitecture | `sparc run architect` | architecture |
| **R**efinement | `sparc tdd` | tester, coder, reviewer |
| **C**ompletion | `sparc run integration` | refinement |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Agents not coordinating | Verify topology matches task type |
| Memory not persisting | Use hive-mind instead of swarm |
| Slow searches | Switch to AgentDB |
| Session lost | Use `hive-mind resume session-id` |
| Hooks not working | Run `claude-flow init --force` |

## Files

```
.claude/skills/flow-coach/
├── SKILL.md    # Main skill file (loaded by Claude)
└── README.md   # This documentation
```

## Related Skills

| Skill | Purpose |
|-------|---------|
| **agentic-coach** | General prompt elevation |
| **prompt-elevation** | Transform vague prompts |
| **sparc-methodology** | SPARC development workflow |
| **swarm-orchestration** | Multi-agent coordination |

## Version

- **Skill Version**: 1.0.0
- **Claude-Flow Compatibility**: v2.7.0+
- **Created**: 2024

## License

MIT

---

**Remember:** Flow Coach never executes without asking. You're always in control.
