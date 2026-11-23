# Thumb Party: notes for coding agent sessions

**New developers / other agents: start with docs/HANDOFF.md.**

- **DeepSeek Harness sessions:** read [docs/HANDOFF.md](docs/HANDOFF.md) section 10 first, then [docs/agent-workflow.md](docs/agent-workflow.md). That file defines the Pro-architect / Flash-worker split and the delegation rules. The flash-worker notes below do not apply to that line.
- **Before using flash-worker (`tools/flash.sh`) in any way, read [docs/flash-framework.md](docs/flash-framework.md).** It says who does what, the two working modes (normal and low-usage), how to write a brief, the unattended runner (`tools/run-jobs.sh`) and the owner's standing rules. Default worker is Haiku (`WORKER=claude`), flash the fallback: [docs/design/claude-only-model.md](docs/design/claude-only-model.md).
- The current milestone's hand-over is its `docs/briefs/<milestone>/STATUS.md`; read it before continuing work.
- Tools are documented in [docs/dev-tools.md](docs/dev-tools.md); code rules in [docs/coding-guidelines.md](docs/coding-guidelines.md) and [docs/review-rules.md](docs/review-rules.md).
- **Batch work:** read [docs/flash-digest.md](docs/flash-digest.md) and use the fixed agents in `.claude/agents/` (`thumb-triage`, `thumb-batch`, `thumb-release`); the routine is in the "Fixed agents" section of the framework.
