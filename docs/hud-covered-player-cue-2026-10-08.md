# HUD-covered player recovery cues

## Source and scope

Parent: `5869ec9074364e48a8b9a62c37a3e804b3f6dbd4`.

`OffscreenPlayerCue.project` previously considered the entire camera frustum
usable. A player projected behind score chips or touch controls therefore lost
their recovery marker. The cue now tests the projected screen position against
the HUD's existing safe rectangle before suppressing the marker. Covered-player
arrows point from the usable rectangle toward the actual projected position.

No camera zoom, collision, AI, scoring or touch-control placement changes.
Existing eligibility still suppresses hidden, eliminated and non-live players.

## Verification

- RED: 58 assertions passed, one failed for a visible but HUD-covered player.
- GREEN: 85 assertions passed, including both camera projections, all four
  covered directions, portrait bounds, behind-camera/far-clip markers and
  hidden-player privacy.
- Full suite: exit 0, 392623 assertions, 174.6 seconds. Strict test-log guard passed.
- Compile: all 430 scripts, exit 0; strict runtime-log guard passed.
- Metal rendering: six captures across Goal Guard, Blast Ball and Colossus,
  four touch slots, Arabic, portrait and landscape; zero automated failures.
- Dedicated offscreen rendering: one/four touch slots in both orientations;
  zero failures for cue presence, chip/control overlap and hidden/result state.
- `git diff --check`: passed.

Raw logs and captures are retained outside the source checkout at
`../qualification-hud-cue-2026-10-08/`.
Full log SHA256:
`81df74e046caaa88656b24b2f2dabdecc4eb3c49fb614422f41d0d1e576253c1`.

The first default-sandbox invocation crashed before test startup while opening
the default user log. An explicit scratch `--log-file` allowed the RED/GREEN
and full suite to complete. Those sandbox logs include macOS system-CA access
errors; the escalated local compile/Metal checks do not. This is not an assertion
that all engine log lines are error-free.

## Remaining gates

Small shared-arena Colossus actors still need readability polish; this repair
does not enlarge them. Metal desktop screenshots do not prove iPhone ergonomics,
battery, heat or real four-person input. No archive, upload or App Review action
was performed.

GitHub jobs `37812970245` and `37813002835` were still live when inspected and
target `78d11abdb35144a6c754414487606093dd5c1435`, not this repair. Their eventual
results cannot qualify this changed runtime source; retain their results as
source-specific evidence and qualify the final release source separately.
