# Rival Reacquisition Reaction Delay

Runtime commit: 99242b886e898cc2c2bea6087eb08364beb350f7.
Branch: fix/kras-rival-reacquisition-delay.
Parent: fd5d94f; inherits the Blast Ball fix and its qualification evidence.

## Defect and Fix

AIBrain previously used first-ever observation credit for can_target. After a
rival was hidden and reappeared, an already-observed rival could immediately
become actionable without earning the configured reaction delay again.

The bounded per-slot visible-since array now records continuous visibility
credit independently of first-seen memory. Hidden samples and hidden/dead
target queries invalidate current targeting credit. Reappearance must be
sampled and remain observed for reaction_time. Last-seen positions and delayed
motion memory remain available; no hidden position is sampled. Round reset
clears reacquisition credit. Zero-delay diagnostic profiles retain their old
behavior. No character speed, damage, movement or difficulty constants changed.

Regression covers all four difficulty profiles: first sight, mature continuous
sight, occlusion, retained memory, fresh reappearance, the threshold boundary,
occlusion detected between history samples, unsampled reappearance and reset.

## Actual Checks

All tests used isolated temporary save directories, Godot 4.7.1 official and
fixed simulation FPS 60. Source edits were complete before these checks.

- ai_visibility: 4041 assertions, exit 0.
- ai_occlusion: 21 assertions, exit 0.
- ai_compound_visibility: 26 assertions, exit 0.
- Compile check: all 415 scripts compile, exit 0.
- Stability: one cycle, 39 matches, zero failures, exit 0.
- Runtime guards for all five checks passed; whitespace check passed.

Logs: /tmp/kras-rival-reacquisition-tests.log,
/tmp/kras-reacquisition-occlusion.log, /tmp/kras-reacquisition-compound.log,
/tmp/kras-reacquisition-compile.log, /tmp/kras-reacquisition-stability.log.
The macOS CA-access diagnostic is retained. The stability fixture deliberately
injects a memory warning; this is not a physical-device warning. Texture,
material, mesh and audio caches reached zero after settling, but process memory
remained about 140 MB versus the 40.7 MB starting sample. This is not proof of
no leaks or stable long-session device memory.

An incorrect --suite=ai invocation selected no tests and exited 1. Its log is
/tmp/kras-rival-reacquisition-ai.log. It is not counted as a successful test;
the runner's exact-name suites were then executed separately as listed above.

## Release Limits

This shared AI behavior affects every controller that uses can_target. Existing
natural balance campaigns on earlier sources do not qualify it. Full regression
and current-source natural balance remain required before release, along with
physical-device and production-network acceptance. No claim of 39 READY games,
no main merge, no phone install, no Railway deploy, no archive/upload or App
Review submission. Existing archive 110 does not contain this fix.
