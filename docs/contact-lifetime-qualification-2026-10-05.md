# Contact Lifetime Regression Qualification

## Source and Scope

- Repository: shary17454/kras-pass; base main: `8aabcd3346a1ba269bafb8b21a0ab92324ea2f4e`.
- Tested fix: `6acf46846d87698352df5941439f29a82b3eb995` on `test/kras-contact-lifetime-rival-fixture`.
- Godot: 4.7.1 official a13da4feb, macOS, headless, fixed 60 simulation ticks.
- Production combat and victory rules are unchanged. The contact-lifetime fixture now uses competitive Ring Rumble and asserts the two fighters are rivals.
- Cooperative boss fixtures independently verify that teammate attacks and body impacts remain blocked while boss/environment damage and individual contribution scoring remain effective.

## Reproduced Failure

Previous-source CI run 37318048800, core job 111789690922, failed the fresh-contact impact assertion. Its intended source was e96f2cab5aacb0e64296faba460d6075dc8bee6e, not the current main commit. Local current-main reproduction produced 359744 passing assertions and one failure at the same expectation. The old fixture used a cooperative boss, where rejecting teammate impact is intentional.

Local failing evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.enOMYp/`. This is retained failing evidence, not a successful qualification.

## Fixed-Source Results

- Full `tools/check_party.sh`: exit 0; evidence `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.STfQQJ/`.
- Compile: 365 scripts passed. Inventory: 404 resources, 21 autoloads, 27 routes, 8 characters, zero inventory issues.
- Complete unit/integration runner: 359746 assertions passed in 161.8 seconds.
- Actual three-lap race regression passed.
- Natural boss defeat probes passed: Colossus seeds 345, 9614, 172; Forge, Dreadnought and Sovereign seed 9614. Expert AI only; not a balance certification.
- Stability: 39 matches, one cycle, four AI, default arenas. Timed rounds shortened; real race laps retained. Zero completion, retained match object, node/orphan, signal, input ownership or logged-runtime-error failures.
- Focused contact suite: 5 assertions passed, `/tmp/kras-contact-lifetime-fixed.log`.
- Focused cooperative boss suite: 140 assertions passed, `/tmp/kras-contact-boss-cooperation.log`. These overlap the full suite and are not added to its count.
- Server: 186 passed, zero failed, six actual-Godot-capture tests skipped; `/tmp/kras-contact-server-tests.log`. The initial sandbox invocation failed to listen on loopback with EPERM; authorized local rerun passed the real WebSocket test.

## Remaining Gates

No claim of sustained memory behavior: the one-cycle stability run does not exercise the three-cycle post-warmup memory-growth gate. No actual-device FPS, thermal, battery, multi-touch/gamepad, real-Internet four-device, all-arena, natural-duration all-game or large-sample balance certification. PR CI still requires independent final verification.

No automatic merge, Railway deploy, current-source Distribution archive, upload, processing verification or App Review submission was performed. The full original development and release scope remains incomplete.
