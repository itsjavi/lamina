---
id: decision-4
title: 'Drive the running app over Apple Events, not a socket or a local HTTP port'
date: '2026-10-07 21:42'
status: accepted
---
## Context

TASK-4 adds `lamina`, a command-line tool that drives the running app (list projects and layers, select, apply
filters and adjustments, export), and TASK-5 wraps the same commands as an MCP server. Both need a request/response
channel from a process outside the app into the App Sandboxed app, with results coming back, and nothing more exposed
than the person's own machine and user.

Candidates (research in doc-1 §7):

- **Apple Events**: macOS's own app automation. A custom event class and id handled with `NSAppleEventManager`; the
  request travels as the event's direct parameter and the result in the reply event.
- **A Unix socket in an app-group container**: the sandboxed app can listen in its group container, and a client of
  the same team can connect.
- **Loopback HTTP or TCP**, as upstream PRs #89 (TCP with a per-launch token and a 0600 discovery file, plus a Python
  stdio bridge) and #91 (Streamable HTTP in the app) did.
- **The URL scheme**: one-way, no results; not enough.

## Decision

Use Apple Events: one event class/id ('Lmna'/'Exec') whose direct parameter is a JSON request and whose reply carries
the JSON result or error.

- The sandboxed receiver needs no entitlement to receive and answer Apple Events, so the app's entitlements don't
  change.
- Consent is macOS's: the first event from a calling app (Terminal, an editor, an agent's host) shows the Automation
  prompt; the choice is per calling app and can be revoked in System Settings › Privacy & Security › Automation.
- The app also refuses events from other Macs (Remote Apple Events, `keyEventSourceAttr`) and from another user's
  processes (`keySenderEUIDAttr`), so only the person's own processes on this Mac can send commands.
- No open port, no `network.server` entitlement, no tokens or discovery files, no Python, no extra service running.
- The sandboxed app can't read or write arbitrary paths, so `lamina` (not sandboxed) does file I/O: the app returns an
  export's bytes and `lamina` writes the file, as #89's bridge did.
- `lamina` is a Swift executable shipped in the bundle (`Contents/Helpers/lamina`); under the hardened runtime it needs
  `com.apple.security.automation.apple-events` (Resources/lamina.entitlements).

Rejected:

- **App-group Unix socket**: an app group needs a team-prefixed group id and a provisioning-backed signature, so even
  Dev and ad-hoc builds would need team signing, and the socket is reachable by any process of the user without a
  consent step unless the app adds its own authentication.
- **Loopback HTTP/TCP**: needs `com.apple.security.network.server`, a per-launch token and its discovery file, and for
  HTTP Origin/Host checks against DNS rebinding — the parts that made #89 and #91 large and that any local process or
  web page could probe. It also keeps a listener open whenever the app runs.

## Consequences

- One Automation prompt per calling app on first use; a caller that is denied gets errAEEventNotPermitted (-1743),
  which `lamina` explains. Commands from a context that can't show the prompt (no GUI session) fail until it's
  allowed.
- Apple Events are macOS only and synchronous per request; the app suspends each event while its command runs, runs
  commands one at a time, and `lamina` waits with a timeout (`--timeout`, default 300 s). Progress can't stream back
  mid-command over this channel; TASK-5 reports progress from its own side.
- Several copies of the app running (a Dev build next to the release one, or two Dev instances) are told apart by
  bundle id (`--dev`, `--app`, `LAMINA_APP`) or process id (`--pid`).
- Payloads are JSON strings; image bytes travel base64 inside them (fine for exports and previews of the sizes the app
  handles; a raw-data parameter is possible later if size matters).
- The rename to Lamina (TASK-6) changes the bundle ids in one Swift constant (`AppIdentity`) and in build-app.sh.
