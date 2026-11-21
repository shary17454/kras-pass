# Quick Play picker layout and expanded visual QA

## Source and fix

Base commit: `b0d311f6fcc5394ef329e8511dcfd0c946736fc5` on
`feature/kras-online-random-rotation`. The runtime candidate fingerprint is
`234b08ecdd5a63a4a6231dde70166ee9dd4f526e268208d731c7b5b8da5da3c4`;
the checkout and isolated Godot copy matched during qualification.

Quick Play used a plain Control with a 160-unit minimum height for cards whose
content requires more space. The card overflowed the allocation and its stats
overlapped the next section. Arabic portrait screenshots reproduced this.
The holder is now a VBoxContainer, so the card's own minimum size participates
in layout. Redundant full-rect anchors were removed. Selection, unlock rules,
match configuration, gameplay and AI were not changed.

## Tests and graphical evidence

- A first diagnostic probe was discarded because its expanded game array did
  not also expand the OptionButton. Its out-of-range errors were fixture errors.
- The corrected pre-fix test failed 376 layout checks without runtime errors.
- Post-fix and final-unit recheck: 385 assertions passed; strict log guards passed.
- The unit covers all 39 game cards and eight character cards, Arabic/English,
  at four window dimensions. It checks allocation and the following section.
- Compile check: all 449 scripts passed, with a clean strict log guard.
- Expanded menu fixture: 23 default-state routes x two locales x four dimensions
  (1280x720, 540x960, 1366x1024, 1024x1366), 184 captures.
- One post-fix full run passed layout checks but failed the strict log guard:
  two ObjectDB instances and one resource remained at exit. This run is rejected.
- A full verbose recheck passed all 184 captures and the strict log guard. An
  eight-case Quick Play verbose probe also passed without the resource warning.
  The warning's root cause was not established; do not describe it as a fixed
  production memory leak.
- The fixture now explicitly shuts down audio and drains two frames plus the
  existing 100 ms audio grace used by other graphical tests. An additional
  eight-case Quick Play check passed with this final teardown and strict guard.
  The full verbose matrix predates this teardown-only fixture change.

The fixture saves PNGs and machine-readable layout reports, requires isolated
storage and a real renderer, awaits the router, checks the requested route,
nonblank rendering, horizontal bounds and Quick Play card containment. It can
target affected default-state routes via `--screens=quick_play`. Match, results,
replay playback and standings are explicitly excluded because they need state.
This is not their graphical acceptance, deep scrolling QA or physical-device QA.

Manual inspection covered the before/after Arabic phone Quick Play, Arabic
phone Local Play, English tablet portrait Quick Play, AlUla race portrait and
the paused magma race image. It did not cover every image interactively.

## Other preserved prior-source checks

All declared game/arena pairs on the base runtime fingerprint
`09f94a79acb24d57c2962993a88493b3a96089240605d7b5c0e825c36d7369c8`:
57 pairs, one touch slot plus three Bots, Arabic, two orientations, two seconds
of additional live play. Initial run: 114 captures, three paused failures
(Sovereign landscape, magma armed race portrait, Siege iron-flats portrait).
Targeted unchanged-source retries passed six captures. Composite coverage is
114 unique passing cases from 120 attempts, not one clean full run. Original
failures are preserved. These checks predate the Quick Play runtime change.

Core CI `38002116389` succeeded on the base commit, with a clean checkout
attestation: 406980 assertions, 448 compiled scripts and 117 stability matches
with zero failures. Its four-peer mixed tournament completed three different
games with matching results and reconnect. This is not candidate-source CI.
Local base-source server tests: 270 passed, six capture-dependent tests skipped.
Base-source npm audit reported zero known dependency vulnerabilities.

## Remaining gates

Evidence is retained at `../qualification-menu-map-matrix-2026-10-10/`, including
the invalid probe, clean failing baseline, rejected exit-warning run, clean
verbose rechecks, map failures/retries and prior-source CI artifacts.

Current-source full CI, full per-game balance/network acceptance, native
iPhone/iPad/controller/performance qualification, production DB authorization
and release-source Distribution archive remain separate open gates. The
original product scope and stage QA/merge requirements remain open. No stage
is marked DONE, no game READY, and no main promotion, Railway deployment,
App Store upload or review submission is performed by this batch.
