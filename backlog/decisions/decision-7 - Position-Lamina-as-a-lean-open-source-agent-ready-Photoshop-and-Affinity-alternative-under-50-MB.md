---
id: decision-7
title: >-
  Position Lamina as a lean, open-source, agent-ready Photoshop and Affinity
  alternative under 50 MB
date: '2026-10-08 15:40'
status: accepted
---
## Context

The README inherited upstream Compositor's pitch, which opened by complaining that Photoshop costs too much. Everyone
knows that already, and it says what Lamina isn't rather than what it is. The rebrand (TASK-6) and the new README and
landing page need one positioning to write from, and adding vectors (m-2) makes "pixels and vectors in one simple app"
part of it.

## Decision

- **Pitch:** a simpler alternative to Photoshop and Affinity for the Mac, for photo work, compositing and vector
  graphics, without the bloat, the subscription or the sign-up. Open source and agent ready: agents drive it from the
  command line and as an MCP server, and can write its project files directly.
- **Tone:** say what Lamina does; no complaints about other apps' prices or features.
- **Size budget:** the app stays under 50 MB. The release build was 25 MB on 2026-10-08, before vector support; the
  budget is checked again once vectors land.

## Consequences

- README, landing page and release notes lead with this pitch.
- The size budget weighs on every dependency and bundled asset: a feature that needs a large library or resource has
  to justify it against the budget, which also backs AGENTS.md's rule of taking only dependencies the system
  frameworks can't replace.
- No accounts or sign-in, which would contradict the pitch.

