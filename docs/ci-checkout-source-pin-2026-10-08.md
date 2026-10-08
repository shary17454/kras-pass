# CI Checkout Source Pin

Repository: shary17454/kras-pass. Branch: fix/kras-ci-checkout-fingerprint.
Initial wiring commit: 4d714f7947006f8e97500105e41f37526ddeaf36.
Final code commit: 0a3aeb7d429e5c82bca9279d88fb23723b96a264.
Parent: 4f990aa97c22ee3d4d98dbc5e830252a00159f2e (PR 211).

## Gap Closed

The summary already required per-artifact commit/run/checkout identity and
consistent start/end source fingerprints. However, the workflow did not supply
the expected fingerprint of the summary's own checkout. A coherent collection
of stale reports could therefore pass the fingerprint consistency check if its
surrounding provenance metadata was mistakenly relabeled.

The summary now calculates its checkout's fingerprint using
tools/balance-source.mjs and passes --source-fingerprint to the existing strict
aggregator. The algorithm mirrors tools/balance_evidence.gd: src/scenes/data/tools,
the seven engine-qualified extensions, project.godot, sorted res:// paths and
raw file SHA256 hashes. Hidden directories and nonqualified extensions are
excluded. Missing required roots and symlinks fail closed.

This is a simulation-source fingerprint, NOT archive, assets, native bridge,
signing, installed-app or physical-device provenance. No runtime gameplay files
or balance thresholds changed.

## Actual Verification

- Five new tests cover exact hash composition, nested edits, exclusions, every
  qualified extension, project settings, missing roots, symlinks and workflow
  wiring. Existing aggregator tests retain stale-source rejection controls.
- Wiring regression tested with the old workflow restored temporarily: exit 1.
  /tmp/kras-ci-checkout-pin-wiring-red.log. The fixed workflow was restored
  immediately and no intermediate version was committed.
- Final focused tests: 83 passed, zero failures/skips.
  /tmp/kras-ci-checkout-pin-final.log.
- Actual Godot 4.7.1 capture and Node computation on this checkout both returned
  373ff382576009d42c54395613580fdf7acb0b017fa41c2afeead79e9ac9dd7e.
  /tmp/kras-checkout-pin-engine.log. The temporary SceneTree probe lived outside
  the checkout; it did not change the source being measured.
- The complete older campaign's artifacts were deliberately checked against
  that current fingerprint: exit 1, mismatched simulation source fingerprint or
  engine. /tmp/kras-ci-checkout-pin-old-rejection.log. Old evidence is retained,
  not relabeled as current or deleted.
- git diff --check passed.

## Current Campaign and Release State

Campaign 37713199729 was dispatched before this tooling-only fix, on source
4f990aa97c22ee3d4d98dbc5e830252a00159f2e, seed offset 1200000. Live GitHub inspection
confirmed it queued, with no completed simulations. It contains the actual
camera/control fixes, but not the new workflow wiring. Its runtime source
fingerprint remains unchanged by this MJS/YAML/test/doc-only commit; revalidate
its artifacts with the explicit current fingerprint when they become available.
Do not restart it merely because it is queued. Prior campaign 37709226998 was
also confirmed live and is not canceled by this change.

This is not completed current 39-game balance acceptance, four-human device QA,
a main merge, Railway migration/deployment, a new local Xcode Archive, Apple
upload, processing or review submission. Those release gates remain open.
