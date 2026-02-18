# Autonomous Cleo

## What This Is

Autonomous Cleo is an AI agent that lives on a VPS and acts as aman's digital brain — handling tasks aman does daily without requiring aman to be at his computer. It starts with automated GitHub PR reviews (triggered by assignment or Discord tags) and expands to Slack/Discord monitoring, meeting notes, and fully autonomous code development tasks delegated via Discord.

## Core Value

Cleo acts on aman's behalf without aman initiating — she monitors, reviews, executes, and reports back.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Cleo monitors GitHub for PRs assigned to aman and reviews them on a configured schedule
- [ ] Cleo immediately reviews PRs when aman is tagged in Discord with a PR number
- [ ] Cleo notifies aman via Discord DM at each stage: starting review, finished, result (approved/blocked + reasons)
- [ ] Cleo asks aman before taking any action on a PR (posts comment, requests changes, approves)
- [ ] Cleo applies per-repo review guidelines (different strictness for Salesforce+TS vs complex TS+Python+AI repos)
- [ ] Cleo runs on a VPS and operates independently when aman is not at his computer
- [ ] Cleo sends task reminders when she sees things assigned to aman in Discord that haven't been acted on

### Out of Scope (v1)

- Slack monitoring — after Discord integration is solid
- Meeting note-taking — requires audio/meeting infrastructure, future phase
- Autonomous code development (task delegation via Discord) — future phase after PR review proven
- Email integration — not mentioned as priority
- Web dashboard — Discord DM is sufficient for now

## Context

- **OpenClaw vs ZeroClaw**: Research needed to determine which is the right headless Claude executor for VPS deployment. Both are candidates for running Claude autonomously on the VPS.
- **Repos in scope**: At minimum, one Salesforce+TS library repo and one complex TS+Python repo with heavy AI code. Each needs its own review protocol.
- **Discord is the primary interface**: All notifications, triggers, and future task delegation will flow through Discord.
- **GitHub is the initial integration**: PRs assigned to aman, or PRs aman is tagged in via Discord.
- **Deployment**: Fresh VPS to be provisioned. Cleo runs as a persistent service.
- **Always-on**: Cleo must work when aman is offline, not just when he's at his system.

## Constraints

- **Tech**: OpenClaw or ZeroClaw for Claude execution on VPS — needs research to decide
- **Interface**: Discord only for v1 (no web UI, no email, no SMS)
- **Actions**: Never takes action on a PR without notifying aman first and getting implicit/explicit approval
- **Scope**: PR review is v1. Everything else is future phases.
- **Deployment**: VPS-hosted, always-running service (not serverless / on-demand only)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Start with PR review | Highest daily pain point, most concrete scope | — Pending |
| Discord as primary interface | Already used, no new tool friction | — Pending |
| OpenClaw vs ZeroClaw | Needs research before architecture decision | — Pending |
| Per-repo guidelines | Different codebases need different review standards | — Pending |

---
*Last updated: 2026-02-18 after initialization*
