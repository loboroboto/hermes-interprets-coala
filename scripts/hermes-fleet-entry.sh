#!/usr/bin/env bash
# hermes-fleet-entry.sh — HERMES_CMD wrapper for per-agent fleet runs (#8/#11).
#
# bootstrap.sh launches the paperclip-hermes-gateway runner with
# HERMES_CMD=/app/hermes-fleet-entry.sh, so the runner invokes THIS script
# (instead of `hermes` directly) for every POST /run. The runner forwards the
# adapter's per-agent env — crucially HERMES_HOME=/data/hermes/agents/<agentId>
# — but it CANNOT override HOME (HOME is in the runner's _PRESERVE set), so the
# only place to give each agent its own ~/.hermes is right here.
#
# What it does, then hands off to the real hermes:
#   1. Lazily, idempotently provision the agent's home from git-tracked config
#      (first /run for a new agentId seeds it; later runs are a no-op).
#   2. For fleet homes only (/data/hermes/agents/*), re-home the process so
#      ~/.hermes resolves to that agent's own home — full per-agent isolation,
#      no cross-contamination via the global ~/.hermes alias bootstrap set for
#      the main agent.
#
# A /run WITHOUT an env.HERMES_HOME override inherits the runner's HERMES_HOME
# (the main home /data/hermes); the case guard leaves that on HOME=/root with
# the existing global alias, so only true fleet homes get re-homed.

set -euo pipefail

HOME_DIR="${HERMES_HOME:?HERMES_HOME must be set by the adapter for fleet runs}"

# 1. Idempotent provisioning (single source of truth, shared with bootstrap).
/app/seed-hermes-home.sh "$HOME_DIR"

# 2. Per-agent HOME isolation for fleet homes only.
case "$HOME_DIR" in
  /data/hermes/agents/*)
    # Self-link so $HOME/.hermes == the agent home once HOME points here.
    ln -sfn "$HOME_DIR" "$HOME_DIR/.hermes"
    export HOME="$HOME_DIR"
    ;;
esac

exec hermes "$@"
