# iOS Scene and Addon Source Attestation

Code commit: `e32927e2324cdaf720892d29da954c0203b0ed25`.
Branch: `fix/kras-ios-scene-source-evidence`, stacked on
`test/kras-local-roster-visual-qa`.
PR: https://github.com/shary17454/kras-pass/pull/214 (draft, not merged).

## Defect and Fix

`project.godot` starts `res://scenes/boot.tscn`, but the native export source
identity did not include `scenes/`. Uncommitted changes to that tracked scene
left both the recorded Git commit and selected input digest unchanged, allowing
the old attestation to pass. Untracked scenes and addon resources were also
outside the source guard.

Include `scenes/` and `addons/` alongside the existing source, data, assets,
native bridge, tooling and export configuration roots. Changes in these roots
must be committed before the source inspection/export record succeeds. A new
committed source cannot reuse an old attestation. Export output hash checks and
required native/engine/game-pack checks remain unchanged.

The guard retains its existing Git-tracked/non-ignored-file scope; this change
does not claim coverage of arbitrary ignored files. The temporary iOS extension
descriptor is still generated from the tracked native template and removed by
the export script. This is a source guard, not a signature, archive-to-source
proof, App Store processing result or physical-device test.

## Regressions

Actual Python fixture repositories exercise tracked changes to scenes/addons,
untracked additions, rejection before commit, digest changes after commit and
rejection of the old export. The previous implementation produced four failed
checks. With the fix, all 15 Python tests pass. The four strict iOS export-log
tests and five balance-source tests also pass.

Logs and the clean source inspection for the code commit are retained under
`docs/qa/ios-scene-source-2026-10-08/`. Before committing the code, inspection
of the actual checkout rejected the dirty release tooling as intended. After
commit, it produced input SHA256
`d11f8555e51a257d5811a58808e8bd225baaab488ea7e488ceeb4a326e2e3774`.

Gameplay fingerprint remains
`373ff382576009d42c54395613580fdf7acb0b017fa41c2afeead79e9ac9dd7e`.
This Python/tooling fix does not justify restarting the running natural-match
campaign; native exports still need their own final source evidence.

## External Gates

Xcode 27.0 (27A266a) and the existing Distribution identity were verified live.
No P12 import, password request, certificate creation or revocation occurred.
Chrome briefly displayed TestFlight 1.1.10 build 107, then redirected to Apple
login when the upload list was opened. That cached initial page is not a full
current build-number inventory. No release number was changed, no new archive
was created and no upload or review submission was performed.

Current-source natural campaign 37713199729 is still running. Its five available
games account for 210 completed matches and retain a Crumble Court spawn-position
warning. Partial evidence is explicitly not release-ready. Production health
returned `ok=true`, `authentication_ready=true`, `multiplayer_enabled=false`;
this is not an online production acceptance test or a fresh deployment.

## Completed Current Gameplay Gate

`sh tools/check_party.sh` completed with exit 0. The run started from the current
gameplay files at `801a1db35256129cee74a750d94ef2759d436670`; the Python guard
fix was committed while it ran, but none of its gameplay/test scripts changed.
The gameplay fingerprint above was verified again after completion.

- Compilation: 423 scripts.
- Inventory: 523 resources, 22 autoloads, 27 routes, 8 characters, zero issues.
- Full Godot tests: 390939 assertions passed, 445.0 seconds.
- Race regression and all six boss checks passed their strict log guards.
- Stability: one cycle, 39 matches, zero failures.
- Main log: `/tmp/kras-current-373-full-gate-2026-10-08.log`.
- Evidence directory:
  `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.gHip61`.

The six actual world captures under that run's `saves-tests/` were supplied via
the `KRAS_*_WORLD_FIXTURE` environment variables to `npm test` in `server/`.
Node 24.18.0: 229 tests passed, zero failed and zero skipped, exit 0. Summary
logs are retained alongside the Python evidence in this document's QA folder.

The stability test intentionally triggers a memory warning to check cache
release. It does not demonstrate absence of sustained memory leaks, thermal
issues or battery use. These headless runs do not replace physical iPhone/iPad
QA, all-map natural balance, Internet multiplayer qualification, production
deployment or final-source local Xcode Archive/signature/upload/review gates.
