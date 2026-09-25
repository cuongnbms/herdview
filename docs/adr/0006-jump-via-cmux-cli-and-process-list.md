# 0006: Jump by driving the cmux CLI and matching Terminal Tabs by their Herdr client process, accepting a dependency on cmux's command-line shape

> Status: Accepted · Date: 2026-09-25

## Context

A Jump has to find the cmux tab attached to an Agent's Session, focus it, and focus the
Agent's pane in Herdr. Neither program records the link between the two: cmux knows each
tab's tty and title, Herdr knows its Sessions and panes, and nothing says which tab shows
which Session. Tab titles are whatever the shell or Herdr last set, so they cannot be
trusted to name the Session.

What does link them is the process on the tab's tty: a Herdr client started as
`herdr --session X` or `herdr --remote R --session X`.

Source: [design spec](../superpowers/specs/2026-09-25-cmux-jump-design.md)

## Decision

Herdview reads `ps -axo tty=,args=` and `cmux --json tree --all` on every Jump. It matches
each Herdr client's tty to the cmux surface with that tty, and acts through the `cmux`
CLI (`rpc surface.focus`, `new-surface`, `new-workspace`) and `herdr agent focus`.

The process list is the one place that states which Session a tab shows, and the CLI is
cmux's public, documented interface, so this needs no configuration and survives cmux
updates better than the alternatives.

## Consequences

A Session attached some other way — a shell alias that renames the binary, a client
started by a script with different arguments — is invisible to a Jump, which then opens a
new Terminal Tab beside it. A cmux release that renames these commands or the tree's JSON
fields breaks Jump until Herdview follows.

## Alternatives considered

| Alternative | Why not chosen |
|-------------|----------------|
| Speak cmux's JSON-RPC socket directly, like `HerdrSocketClient` does for Herdr | The socket protocol and its capability-token auth are undocumented; the CLI wraps them and is the supported surface. |
| Drive cmux through Accessibility (click its sidebar and tabs) | Needs an Accessibility grant and breaks on any layout change. |
| Match tabs by title | Titles are set by the shell or the agent inside and rarely name the Session. |
| A config table mapping Sessions to cmux workspaces | Goes stale as tabs move; the process list is always current. |
