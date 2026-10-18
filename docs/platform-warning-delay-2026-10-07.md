# Platform Warning Reaction Qualification

Runtime: 3d4de5178556c61b09c44dac9eb9c9980c2bb720.
Branch: fix/kras-platform-visible-shove; continuation of PR 152.
No main merge, Railway change or Apple submission.

## Fairness Correction

The visible-floor check did not itself enforce a reaction delay before using
a newly seen warning under a rival. Platform now tracks one nearby visible
floor danger and waits for the configured reaction_time. Hidden, restored,
out-of-range and absent cues discard credit; a different floor starts a new
delay. Round reset clears the observation. Like existing boss cue handling,
the boundary comparison uses a one-microsecond numerical tolerance.
Ordinary aggression remains independent of the warning. No additional
per-frame tile scan, stat bonus, hazard schedule read, difficulty tuning,
timer reduction or scoring change was introduced. Observation begins when
the nearby warning is inspected at an ordinary decision; it is not an exact
render-frame event time or a complete delayed floor-perception framework.

## Tests

Identical added four-tier fixture: 3965 passed and 32 failed before the
runtime change; 3997 passed after it. Tests exercise first observation,
just-before and exact reaction threshold, hiding/reappearance, solid-floor
restoration/new warning, and round reset. The previous hidden-floor tests
remain present. Logs: `/tmp/kras-platform-delay-{red,green}.log`.

The full `sh tools/check_party.sh` gate exited 0 on this runtime:
398 scripts compile; 491 resources, 22 autoloads, 27 routes, eight characters,
zero inventory issues; 371732 assertions in 354.0 seconds; actual race and
six boss probes pass; 39 stability matches, zero failures. Cache-release
settled memory was 133194301 bytes, with zero cached materials/meshes/textures.
Runtime files were unchanged during the gate; their commit was recorded while
the same gate ran. No source rewrite or test restart occurred.

Evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.rK0SAm`.
Driver log: `/tmp/kras-platform-delay-full.log`.
Save-write and Router-load error messages are deliberate fault fixtures;
the stability memory warning is deliberate too. The strict log guards passed.
One stability cycle is not long-term leak or physical performance proof.

Server suite used all six newly generated Godot world fixtures from that
run's saves-tests directory: 204 pass, zero fail/cancel/skip, 2907.1 ms,
exit 0. Log: `/tmp/kras-platform-delay-server.log`.

## Natural Matched-Seed Measurement

24 baseline + 16 matched difficulty + two stress rounds completed naturally
with offset 600000. Baseline seeds and difficulty character/seed/Expert-slot
assignments match platform-visible-shove-natural-600000.json exactly.
No runtime change occurred during simulation; fingerprint start=end:
`e7b76b27bcbfbb2f5e241f3b6b5965be1c745785d93efc171613763afef3e978`.

| Measurement | Visible-only parent | Reaction-delay runtime |
| --- | --- | --- |
| Expert score share | .59375 | .54375 |
| Slot bias | .0833333 | .2083333 |
| Character bias | .0833333 | .0833333 |
| Mean duration | 12.6125 s | 11.8806 s |
| Report flags | none | none |

Both stress cases passed; strict runtime guard passed. Report:
platform-warning-delay-natural-600000.json. Log:
`/tmp/kras-platform-delay-natural.log`.
This fairness correction is not a balance improvement claim: this sample's
Expert score share decreased and spawn disparity increased, despite the
report not triggering a flag. Retain both observations for larger independent
balance review. A short mean duration also needs gameplay pacing review;
do not alter the timer or force winners to make a passing report. No READY
promotion or broad statistical conclusion follows from this small sample.

## Device and Signing Availability

Fresh local Xcode 27 devicectl probes found the physical iPhone 16 Pro Max
connected by wire, paired, booted, iOS 27.0.1, Developer Mode enabled.
Availability does not prove it is unlocked or that a game was installed/run.
An explicit install approval was requested because the original Bundle ID
may replace its installed store app; no install or data deletion occurred.

Keychain still exposes existing Distribution C81811A21B592B030D57CD5B180227BDDADEA4C1
and Development 07444B824C676576DA43BA0C6396D88FEC339893 identities.
Existing QA profile 469a0687-f6f1-4b5a-bfb6-5ec2584fdfc0 matches
4HM66AD594.com.shary.kraspass, includes the phone and the installed Development
certificate, Apple sign-in entitlement, expiry 2027-10-03.
Existing store profile 91bc3a38-3753-4ed6-9f8b-a26974ff9d5e matches the same
application/team and installed Distribution certificate, expiry 2027-09-19.
No P12/password, new/revoked certificate or profile change was used.
These metadata checks are not a signed archive, signature validation or upload.

Chrome still displays ASC login with authResult=FAILED. No valid current
build inventory or review state is verified. Parent Xcode 27 unsigned export
was dd775f94787137b4a951039c881340b95453bd90 and does not contain this runtime.
Final source/number freeze and a new local signed archive remain required.

## Remaining Scope

All-game balance/perception/polish, physical phone/tablet gameplay, sustained
FPS/thermal/battery/controller QA, approved source promotion and production
backup/restore/migration/protocol deployment, native Apple auth/API/Internet
acceptance, valid ASC session and version/build selection, fresh local Xcode
27 Distribution Archive/signature, upload, processing and separate review
submission remain open. No READY or full-product-completion claim is made.
