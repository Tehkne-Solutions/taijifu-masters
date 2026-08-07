# Remote-first production and observability

Signature: Tehkné Solutions

## Operating rule

The default production path is GitHub connector/API -> branch -> pull request -> remote CI -> merge. A local clone is an exception reserved for operations that the connected remote tools cannot execute safely, especially exact binary publication or Godot runtime benches that require a native engine process.

## Local-use exception gate

Before asking for local execution, record all three conditions:

1. the remote connector or CI path was attempted or verified unavailable;
2. the local operation is materially safer or technically required;
3. the local step has a deterministic verification command and produces evidence that can return to the repository.

## Observability layers

1. Product telemetry: matches, rounds, Tai/Ji/Fu route time, combat metrics and player-facing diagnostics.
2. Runtime health: startup, shutdown, crashes/errors, queue depth, transport health and degraded/offline state.
3. Performance: frame timing, load timing, scene transitions and slow operations.
4. Production telemetry: build SHA/version, platform, debug/release context, gate results and deployment identity.
5. Playtest evidence: participant-safe session IDs, reports and local fallback export.

## Data handling

Do not emit passwords, authorization values, secrets, tokens or email addresses. Prefer pseudonymous participant/session identifiers. The remote transport must be configurable and must degrade to local spool without breaking gameplay.

## Delivery model

ObservabilityRuntime owns generic event transport and health. MatchTelemetry remains the gameplay-domain source of truth. Integration between them must be additive: a telemetry transport failure can never block a round, match, input or rendering path.

## Production optimization

- prefer one larger verified PR over many tiny local handoffs;
- use remote branches for generated text/code/config artifacts;
- make CI gates self-describing and machine-readable;
- keep temporary transport/scaffolding out of main;
- binary assets must be hash-verified before promotion;
- every PASS must be backed by a test, runtime evidence or deterministic hash check.
