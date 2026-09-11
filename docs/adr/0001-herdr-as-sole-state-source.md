# 0001: Take agent status from Herdr only, accepting that agents outside Herdr are invisible

> Status: Accepted · Date: 2026-09-11

## Context

AgentPet derived agent state from each agent's lifecycle hooks. For Claude Code the hooks
miss permission-approval results and Esc interrupts, and "asked a question" had to be
guessed from the assistant's final text with English-only heuristics. The result was often
wrong.

Herdr classifies `idle`, `working`, and `blocked` for Claude Code, Codex, and most agents
from the terminal screen it owns (bottom-buffer snapshot plus OSC title and progress,
matched against per-agent TOML manifests it updates remotely). Only agents with complete
lifecycle hooks (Pi, OpenCode, Kimi, and a few others) use hooks as the authority. Herdr
exposes the result over a local socket as `agent.list` and events.

Source: [design spec](../superpowers/specs/2026-09-11-herdpet-design.md)

## Decision

HerdPet reads Status from Herdr's socket API and never computes it. There are no hooks,
no transcript reading, and no wrapper command.

This wins because Herdr already solves screen-based detection and keeps its manifests
current; reproducing it would mean owning a PTY and a VT emulator, which AgentPet does not.

## Consequences

An agent that runs outside a Herdr pane is not shown at all. A Herdr `done` persists until
that tab is focused inside a Herdr client, so a done Agent can sit in the list for a long
time; this is Herdr's semantics, not a HerdPet bug.

## Alternatives considered

| Alternative | Why not chosen |
|-------------|----------------|
| Keep hooks, add PostToolUse and a staleness timeout | Still cannot see Esc interrupts or approval results without a screen. |
| Read the terminal window title (Claude's spinner / `✳` glyph) | Needs Accessibility permission, breaks under tmux, cannot detect `blocked`. |
| Turn `agentpet run` into a PTY proxy and port Herdr's manifests | Substantial VT work, and the rules would drift from Herdr's remote updates. |
