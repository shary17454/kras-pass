# Four-Local-Player Visual QA

Repository: shary17454/kras-pass. Branch: test/kras-local-roster-visual-qa.
Probe code commit: 5eba591ccda6973197c6300da6cd952ecdcd26c3.
Gameplay source fingerprint:
373ff382576009d42c54395613580fdf7acb0b017fa41c2afeead79e9ac9dd7e.

## Coverage Added

The visual probe previously always used one human slot plus three AI. It now
accepts --humans=1 through --humans=4, assigns every human slot a touch device,
verifies the actual TouchSource count and slot identities, and checks each
control's bounds against its own player's region. Reports record the actual
human count, touch slots and control-bound result. Invalid values fail instead
of silently reverting to the old roster.

Only test tooling changed. Source fingerprint matched before and after both
render runs. Existing runtime camera, physics, rules and assets did not change.
The render runs started on the exact candidate probe files, which were committed
unchanged while the first run was active; they were not launched from an already
clean probe commit.

## Completed Evidence

- Godot 4.7.1 official, actual Metal renderer on macOS.
- Four local touch slots, zero AI, all 39 catalogue games, one default arena per
  game, portrait 540x960 and landscape 1280x720, Arabic and English.
- 156 captures total: 78 per language. Zero failures in the specified checks.
  Each game has exactly one capture in each orientation; every row has slots
  [0,1,2,3], human_count=4 and valid per-player control bounds. Verified against
  the actual data/minigames.json catalogue, not only a hardcoded image count.
- Reports retained under docs/qa/local-roster-2026-10-08/four-local-{ar,en}.json.
  Full images: /tmp/kras-current-four-local-{ar,en}/screenshots.
- Manually inspected Arabic Scrap Karts portrait, Crumble Court portrait and
  landscape, English tank_arena portrait and goal_guard landscape. Four close
  vehicle views, player labels and independent control regions render; this is
  not manual acceptance of all 156 images.
- Visual input policy: 14 assertions passed. CLI --humans=0 returned exit 2 with
  the intended validation error. /tmp/kras-local-roster-policy.log and
  /tmp/kras-local-roster-invalid.log. The negative log is not a runtime failure
  in either completed render run.
- Party suite: 4171 assertions passed. Includes geometry for two, three and four
  local regions across the catalogue, input customization and tournament rules.
  /tmp/kras-current-local-party.log.
- All 423 scripts compile. /tmp/kras-local-roster-compile.log.
- Strict completed-test/runtime/import log guards passed on the positive test,
  compilation and both rendering logs. git diff --check passed.
- npm audit --omit=dev --ignore-scripts: zero known vulnerabilities, exit zero.
  Raw result retained as docs/qa/local-roster-2026-10-08/dependency-audit.json.
  This is not an application-security or production-auth audit.

## Not Yet Proven

These are four configured local-human slots, not four physical people actively
playing. The captures follow two playing seconds after presentation is skipped.
They are spawn/layout/render smoke evidence, not movement/combat acceptance,
every map, every player count's live rendered session, sustained frame time,
memory/thermal/energy measurements, or physical iPhone/iPad QA.

Natural balance campaign 37713199729 remains separate; its queued status is not
39-game balance success. No release-readiness threshold was loosened and no game
was promoted to READY from these screenshots alone. No main merge, Railway
deployment/migration, new signed native Archive, Apple upload, processing or
review submission occurred in this work.
