---
name: human-onboarding-handshake
description: >
  Use as the FIRST action of every session, before any company-affecting
  work. Implements the onboarding gate (fleet epic #8, slice #20): until a
  human has explicitly onboarded this agent, the only permitted actions are
  introducing yourself and requesting go-ahead — no company mutations. Owns
  the per-agent `humanOnboarded` flag in this home's onboarding/state.json.
  Trigger phrases: first contact, am I onboarded, onboarding handshake,
  introduce yourself, awaiting go-ahead, can I start, provisional agent,
  human onboarding, gate.
version: 1.0.0
tags: [coala, meta, onboarding, gate, lifecycle, group]
---

# Human-Onboarding Handshake (CoALA §4.1 observe, §4.2 dialogue, §6.3 escalate/await)

The gate that runs before any company-mutating work. A freshly onboarded fleet
agent is **provisional**: it must speak with its human, introduce itself, and
get an explicit go-ahead before it does anything to the company. This skill owns
the per-agent flag that records that handshake and survives restarts.

## The Flag

State lives in **`$HERMES_HOME/onboarding/state.json`** — this agent's own home,
so it is per-agent by construction (the fleet wrapper re-exports `HERMES_HOME` to
`/data/hermes/agents/<agentId>` before launching). Schema:

```json
{
  "humanOnboarded": false,
  "agentId": "<this agent's id>",
  "firstContactAt": null,
  "onboardedAt": null,
  "onboardedBy": null,
  "channel": null
}
```

**Read it fail-closed:** missing, unreadable, malformed, or `humanOnboarded`
anything other than literal `true` ⇒ treat as **ungated**.

**Do NOT store this flag in USER.md.** `hermes.toml [context].user_md` points at
the absolute `/data/hermes/USER.md` (the shared main home), so a flag written
there would leak across the whole fleet and onboard every agent at once. The
state file is the only per-agent location.

## When to Use

- The **first action of every session**, before Propose — read the flag to learn
  whether you are gated.
- Before any candidate action that would mutate the company while the flag is
  unknown or false.
- When an inbound message might be the human's go-ahead.

## Procedure

1. **Observe** (§4.1). Read `$HERMES_HOME/onboarding/state.json` via the
   filesystem tool. Missing ⇒ create it with `humanOnboarded: false` and
   `agentId` set; treat as ungated. Narrate this read — it is an explicit OBSERVE
   grounding action.
2. **If `humanOnboarded` is `true`** ⇒ the gate is open. Exit this skill; resume
   the normal §4 decision cycle. Do **not** re-introduce yourself.
3. **If ungated and no human message is present** (e.g. a heartbeat run) ⇒ this is
   an **Escalate/await** state (§6.3): do no work. Compose the intro per SOUL.md
   "First contact" — who you are, that you are provisional, and one explicit
   request for go-ahead (what you should own + permission to start). Emit it as
   the run's reply and end the cycle "awaiting onboarding". Set `firstContactAt`
   on the first such cycle.
4. **If ungated and a human message is present** ⇒ classify it:
   - **Explicit go-ahead** (clear affirmative, or an assignment of what to own) ⇒
     go to step 5.
   - **Ambiguous** ⇒ ask exactly one clarifying question (SOUL.md: one question at
     a time) and stay gated. A heartbeat is never consent.
5. **Unlock** (§4.5 learning action — narrate it). Write `humanOnboarded: true`,
   `onboardedAt`, `onboardedBy` (who gave the go-ahead), and `channel` (where).
   Acknowledge briefly, then resume the normal cycle. The next session passes the
   gate on the cheap read in step 1–2.

## Pitfalls

- **Treating a heartbeat as consent.** A periodic tick with no human is the
  await state, not permission. Re-emit the intro; do not start work.
- **Flipping the flag on an ambiguous message.** When in doubt, ask one question
  and stay gated. The flip is irreversible in spirit (you start acting).
- **Writing the flag to USER.md.** Leaks across the fleet — see The Flag.
- **A "harmless" read that mutates.** While ungated, even retrieval is limited to
  read-only context needed to compose the intro. No claims, no board moves.
- **Re-introducing after onboarded.** Once the flag is `true`, never re-run the
  intro — it reads as amnesia.

## Verification

A correct gated cycle leaves a transcript where:

- The `state.json` read is the **first** action, named explicitly.
- An ungated run contains only the intro + go-ahead request and **zero** company
  mutations (git/GitHub/board untouched).
- The unlock is a single explicit, timestamped learning action recording
  `onboardedBy` and `channel`.
- A later session passes the gate cheaply with no re-introduction.
- The file is at `/data/hermes/agents/<id>/onboarding/state.json` — a second
  agent's gate is independent (its own flag still `false`).
