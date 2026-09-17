# Quota for Claude, Codex, OpenCode Go and Grok

Date: 2026-09-17
Status: approved in conversation, awaiting review of this document

## Purpose

Show, in the window, how much of each Provider's Quota has been used and when each
Window resets, so a glance tells whether the herd is about to hit a limit.

The agents Herdview lists run on the local Mac and on remote Hosts, but they all spend
the same accounts. A Quota belongs to a Provider, not to a Host, and it is read once,
on this Mac.

Reference: [stablyai/orca](https://github.com/stablyai/orca) (MIT) reads the same
numbers in `src/main/rate-limits/`. This design takes its endpoints for Claude, Codex
and Grok and deliberately none of its fallbacks (CLI PTY scraping, `codex app-server`,
token refresh). For OpenCode Go it does not take orca's approach at all — see below.

## Scope

In:

- Four Providers: Claude (Claude Code subscription), Codex (ChatGPT plan), OpenCode Go,
  Grok.
- Credentials read from this Mac only, at their default locations.
- Claude's per-model weekly limits (`weekly_scoped`, today "Fable").
- A Quota card at the top of the main window.

Out:

- Reading credentials on remote Hosts.
- Refreshing, writing or rotating any token; launching any CLI.
- Codex's `additional_rate_limits` (e.g. GPT-5.3-Codex-Spark), Codex reset credits,
  extra-usage/credit balances, dollar amounts.
- Config keys, including `CODEX_HOME`, `GROK_HOME` and `CLAUDE_CONFIG_DIR`: an app
  launched from Finder does not inherit the shell environment, so honouring them would
  work only sometimes.
- Notifications about Quota, and anything in the menu bar item.

## Providers

Every endpoint below is undocumented. Each was called with this Mac's real credentials
on 2026-09-17 and returned 200 with the shape described. The fixtures for the tests are
those responses with `user_id`, `account_id` and email removed.

All four report **used** percent. Herdview uses used percent everywhere and never
converts to remaining.

### Claude

- **Credential**: macOS Keychain, generic password, service `Claude Code-credentials`,
  read with `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`.
  The value is JSON; the token is `claudeAiOauth.accessToken`. `expiresAt` is ignored —
  the server decides.
- **Request**: `GET https://api.anthropic.com/api/oauth/usage` with
  `Authorization: Bearer <token>`, `anthropic-beta: oauth-2025-04-20`,
  `User-Agent: claude-code/2.1.0`.
- **Response → Windows**: from `limits[]`, in order:
  - `kind == "session"` → `5h`
  - `kind == "weekly_all"` → `week`
  - `kind == "weekly_scoped"` → `week · <scope.model.display_name>` (skipped when there
    is no display name)
  - any other kind is ignored.

  Each entry has `percent` and `resets_at`. When `limits` is absent or yields no Window,
  fall back to `five_hour` → `5h` and `seven_day` → `week`, each with `utilization` and
  `resets_at`.
- **`resets_at`**: an ISO-8601 string with a UTC offset and up to six fractional digits
  (`2026-09-17T14:00:00.551304+00:00`), which `ISO8601DateFormatter` does not parse as
  is. A number is epoch seconds, or milliseconds when above 1e10. `null` → no Reset.

### Codex

- **Credential**: `~/.codex/auth.json`, fields `tokens.access_token` and
  `tokens.account_id` (optional).
- **Request**: `GET https://chatgpt.com/backend-api/wham/usage` with
  `Authorization: Bearer <token>`, `User-Agent: codex-cli`, `OpenAI-Beta: codex-1`,
  `originator: Codex Desktop`, and `ChatGPT-Account-Id: <account_id>` when present.
- **Response → Windows**: `rate_limit.primary_window` then
  `rate_limit.secondary_window`, either may be `null`. Each has `used_percent`,
  `limit_window_seconds` and `reset_at` (epoch seconds). The label comes from the
  duration: 18000 → `5h`, 604800 → `week`, anything else → a compact duration
  (`3h`, `2d`, `90m`), and `limit` when the duration is missing. `additional_rate_limits` is ignored. A `prolite` plan today returns a
  weekly primary window and no secondary.

### OpenCode Go

- **Credential**: `~/.local/share/opencode/auth.json`, field `opencode-go.key`.
- **Request**: `GET https://opencode.ai/zen/go/v1/usage` with
  `Authorization: Bearer <key>`.
- **Response → Windows**: `usage.rolling` → `5h`, `usage.weekly` → `week`,
  `usage.monthly` → `month`; each has `percent` and `resetsAt` (ISO-8601 with
  milliseconds, `Z`).
- **Errors**: 401 `AuthError` → sign-in expired; 403 with `error.type ==
  "EntitlementError"` → "no Go subscription".

Orca scrapes the opencode.ai dashboard with a session cookie the user pastes in. This
endpoint was found in opencode's own source
(`packages/console/app/src/routes/zen/go/v1/usage.ts`) and takes the key the CLI already
stores, so there is no cookie and no secret-entry flow.

### Grok

- **Credential**: `~/.grok/auth.json`, an object keyed by issuer. Prefer the key equal to
  `https://auth.x.ai` or starting with `https://auth.x.ai::`; otherwise the first other
  issuer with a key, in sorted order so the choice never depends on dictionary order. Fields `key` (the token) and `user_id` (optional).
- **Request**: `GET https://cli-chat-proxy.grok.com/v1/billing?format=credits` with
  `Authorization: Bearer <key>`, `X-XAI-Token-Auth: xai-grok-cli`,
  `Accept: application/json`, and `x-userid: <user_id>` when present.
- **Response → Windows**: fields sit under `config` (or at the top level). One Window:
  `usedPercent = creditUsagePercent`, Reset `currentPeriod.end`, else
  `billingPeriodEnd` (ISO-8601, six fractional digits). The label comes from
  `currentPeriod.type`: `USAGE_PERIOD_TYPE_WEEKLY` → `week`, `…_MONTHLY` → `month`,
  otherwise `period`.
- **Missing percent**: proto3 JSON drops zero values, so when `creditUsagePercent` is
  absent but `currentPeriod` is present, the Window is 0%. With neither, no Window.

## Core (HerdviewCore, pure, unit tested)

- `QuotaProvider`: `claude`, `codex`, `opencodeGo`, `grok`; a display name, the
  sign-in command to suggest (`claude`, `codex`, `opencode`, `grok`), and the
  `AgentKind` whose icon it uses (`.claude`, `.codex`, `.opencode`, `.grok`).
- `QuotaWindow { label: String, usedPercent: Double (clamped 0…100), resetsAt: Date? }`.
- `QuotaReport { provider, windows: [QuotaWindow], fetchedAt: Date }`.
- `QuotaCredentials`: one parse function per source — Claude's Keychain JSON, Codex's
  `auth.json`, OpenCode's `auth.json`, Grok's `auth.json` — each `Data → credential?`.
  `nil` means not signed in.
- `QuotaRequests`: `credential → URLRequest` per Provider (URL, headers, 10 s timeout).
- `QuotaParsers`: `Data → [QuotaWindow]` per Provider. Lenient: a Window that cannot be
  read is skipped; the response fails only when no Window can be read.
- `QuotaOutcome.classify(provider, status, body, retryAfter, now)` → one of
  `.report([QuotaWindow])`, `.signInExpired`, `.noSubscription`,
  `.rateLimited(until: Date)`, `.failed(reason)`. Mapping:

  | Input | Outcome |
  |---|---|
  | 200, at least one Window | `report` |
  | 200, no Window | `failed("unreadable response")` |
  | 401; 403 other than OpenCode's `EntitlementError` | `signInExpired` |
  | OpenCode 403 `EntitlementError` | `noSubscription` |
  | 429 | `rateLimited(until: now + Retry-After)`, default 15 min, capped at 1 h |
  | other status | `failed("HTTP <status>")` |

- JSON numbers are told apart from JSON booleans by CoreFoundation type ID:
  `JSONSerialization` returns both as `NSNumber`, and a `0` passes `is Bool`, which
  would drop every 0% Window.
- `QuotaEntry.applying(outcome)` keeps the last report through sign-in expired, rate
  limited and failed, and drops it on no subscription, where old numbers would be wrong.
- `QuotaSchedule.isDue(trigger, lastStarted, rateLimitedUntil, now)` decides when a
  Provider is fetched (see QuotaMonitor).
- `QuotaFormat`: `"19%"`, the time to Reset (`4d`, `1d5h`, `1h36m`, `36m`, `<1m`),
  `"reset pending"` when the Reset is in the past, `"updated 23m ago"`.

## App

### CredentialReader

Reads the four sources and hands the bytes to `QuotaCredentials`.

- Files: `FileManager.contents(atPath:)`. A missing file → not signed in.
- Claude: runs `/usr/bin/security` with its own `Process`, not through `ProcessRunner`.
  `ProcessRunner` puts stderr into its error, and the callers `NSLog` errors; stdout
  here is a token. Exit 44 (item not found) → not signed in; any other non-zero exit →
  `failed("Keychain access denied")`. Claude Code writes that item with the same
  `security` binary, so no access prompt is expected; if macOS shows one, "Always
  Allow" answers it for good.
- Nothing read here is ever logged.

### QuotaMonitor

- One fetch per Provider, run independently with `URLSession`: a slow or failing
  Provider never holds up another's row.
- Runs only while the window is visible: every 5 minutes, and at once when the window
  is shown, at most once every 60 s. The window controller tells the monitor when it is
  shown and hidden.
- A Provider that is `rateLimited` is skipped until its time passes.
- Logs `herdview: quota <provider>: <outcome>` with the HTTP status. Never a token and
  never a body.

### QuotaStore

`@MainActor ObservableObject`, one entry per Provider, in the order Claude, Codex,
OpenCode Go, Grok:

- `.loading` — before the first fetch.
- `.notSignedIn`
- `.ok(QuotaReport)`
- `.problem(message, last: QuotaReport?)` — sign-in expired, no subscription, rate
  limited, failed. `last` is the most recent successful report, kept however old it is.

A fetch in flight leaves the entry as it was: no spinner, the last numbers stay.

### The Quota card

The first card in `AgentListView`, above the Hosts, labelled `Quota` in the host
label's type, on the same card surface. One row per Provider:

```
QUOTA
[claude]   Claude     5h ▓▓░░░░ 19% · 1h36m    week ▓▓▓░░░ 28% · 4d
                      week · Fable ▓░░░░░ 10% · 4d
[codex]    Codex      week ░░░░░░ 0% · 6d
[opencode] OpenCode   5h ░░░░░░ 0% · 4h   week ▓░░░░░ 19% · 3d   month 1% · 29d
[grok]     Grok       week ▓▓▓▓▓▓ 100% · 2d
```

- Icon from `AgentIcons.image(for:)`, then the Provider name, then its Windows, which
  wrap onto further lines as the window narrows.
- A Window is a label, a thin bar, the percent and the time to Reset. At 90% or more
  the bar turns orange, matching the `blocked` colour, and the percent turns primary
  and semibold. Text never turns orange: as `StatusColor.swift` says, orange text does
  not reach a readable contrast on a light window at 11pt.
- `.notSignedIn`: the name, then "not signed in" in secondary text.
- `.problem` with `last`: the last Windows drawn dimmed, then the message and
  "updated 23m ago". Messages: "sign-in expired — run claude", "no Go subscription",
  "rate limited", "unreadable response", "Keychain access denied", "HTTP 500".
- `.problem` without `last`: the name and the message only.
- `.loading`: the name only.

The card's times move with the list's existing half-second tick; no new timer.

## Testing

`swift test` cannot run on this Mac (no XCTest). Tests are written as XCTest files in
`Tests/HerdviewCoreTests` as usual and run through the standalone `swiftc` shim
recorded in the project memory.

- `QuotaParsersTests`: each Provider against its real fixture; Codex with a `null`
  secondary and with an unrecognised duration; Claude without `limits` (fallback) and
  a `weekly_scoped` entry without a display name; Grok without `creditUsagePercent`;
  percent clamping; fractional-second timestamps.
- `QuotaCredentialsTests`: each source, present, missing fields and malformed; Grok
  preferring `https://auth.x.ai::<uuid>` over another issuer.
- `QuotaRequestsTests`: URL and headers per Provider, optional headers omitted when
  their field is absent.
- `QuotaOutcomeTests`: every row of the classify table, including `Retry-After`
  default and cap.
- `QuotaFormatTests`: percent, time to Reset, reset pending, updated-ago.

By hand, with the built app: the card's numbers match the probe script's for all four;
renaming `~/.grok/auth.json` shows "not signed in" on the next refresh; the window
hidden for over 5 minutes makes no requests (the log is quiet). The card's look is
confirmed by the user, since this terminal cannot capture the screen.

## Documentation

- README: a Quota section — what is shown, where each credential is read from, that
  nothing is refreshed so a Provider whose CLI has not run for a while shows "sign-in
  expired" until it runs, and the possible Keychain prompt.
- `CONTEXT.md`: Provider, Quota, Window, Reset.
- ADR 0005: read Quota from Provider APIs with the CLIs' stored credentials, never
  refreshing them.
