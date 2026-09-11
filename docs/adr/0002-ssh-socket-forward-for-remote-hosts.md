# 0002: Reach remote Herdr by forwarding its Unix socket over SSH, accepting one ssh process per running Session

> Status: Accepted · Date: 2026-09-11

## Context

Herdr listens only on a local Unix socket; there is no HTTP or network listener. AgentPet
reached remote machines with `agentpetd`, a Go daemon deployed and run as a service on each
box. Remote Hosts here run one named Herdr Session per project, several at a time.

Source: [design spec](../superpowers/specs/2026-09-11-herdpet-design.md)

## Decision

For each running remote Session, HerdPet spawns
`ssh -N -L <local.sock>:<remote socket_path> <host>` and talks the same newline-delimited
JSON protocol to the local end that it uses for local Sessions. Sessions are discovered with
`herdr session list --json` over ssh every 30 seconds.

This wins because nothing is installed or kept running on the remote machine beyond Herdr
itself, and the socket client is one code path for local and remote.

## Consequences

Each running remote Session costs one long-lived ssh process; the forward must be respawned
with backoff when it exits. The remote socket path comes from Herdr's own `session list`
output and is absolute, because `-L` does not expand `~` on the remote side. SSH keys must
be usable without a passphrase prompt, since a GUI app cannot show one.

## Alternatives considered

| Alternative | Why not chosen |
|-------------|----------------|
| Poll `ssh host herdr agent list --json` | A new ssh connection per poll per Session, or ControlMaster management, for the same data. |
| A daemon on the remote host bridging the socket to HTTP | Reintroduces a deploy and a service to keep alive on every machine. |
