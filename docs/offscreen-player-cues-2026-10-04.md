# Off-screen player recovery cues

## Scope and source

Branch: `feature/kras-offscreen-player-cues`, based on main
`f29824f82d6f34d6d5e4b090befa17e792be6f94`.
This does not integrate the independent SQLite audit, endpoint authority, or
zone peer fixture branches. No main merge or Apple submission is claimed.

## Implementation

- MatchHUD owns one noninteractive, reusable cue per player slot. Its existing
  throttled refresh updates positions without spawning nodes each frame.
- Actual camera projection and global transform drive the arrows, including
  perspective, orthographic, rotated cameras, behind-camera targets, and
  players clipped by the far plane. A distant target straight ahead points
  forward rather than incorrectly using the behind-camera fallback.
- A visible player inside the view needs no marker. Hidden, freed, absent,
  eliminated, and non-live-round players are excluded.
- Each cue uses the existing player color and symbol, not color alone.
- HUD score-chip extents, platform safe insets, and the actual touch control
  rectangles define a safe area. Custom positions and sizes are respected.
- Same-edge markers are separated without altering their directional arrows.
  If the viewport has insufficient space, an extra cue is omitted rather than
  overlapping other symbols. Score chips remain available.
- No scoring, movement, network authority, or AI perception rules change.

## Executed checks

- Godot 4.7.1, macOS: focused cue suite, 58 assertions passed.
  `/tmp/kras-offscreen-far-tests.log`
- Input sources regression: 293 assertions passed.
  `/tmp/kras-offscreen-input-regression.log`
- All-script compilation: 334 scripts compiled.
  `/tmp/kras-offscreen-far-compile.log`
- Renderer QA: Metal on macOS, landscape 1280x720 and portrait 540x960,
  one and four human touch slots: zero failures. Assertions cover all four
  markers, viewport containment, score-chip/control overlap, hiding a fighter,
  and hiding all markers at results. Screenshots inspected visually.
  `/tmp/kras-offscreen-far-visual.log`
  `/tmp/kras-offscreen-{portrait,landscape}-{1,4}-touch.png`
- `git diff --check` and focused test/compile/runtime log guards passed.

## Remaining qualification

Two full local regression attempts were stopped because source corrections
were made while they were running: touch bounds/separation, then far clipping.
Neither attempt is reported as a completed or final-source pass. The focused
final checks above cover these corrections. Exact-source full CI,
all 39 games/maps, physical iPhone/iPad, unusual safe insets, and FPS/thermal/
battery qualification remain release gates. Render fixtures deliberately move
actors off-screen and freeze physics; they are UI tests, not real match,
network, fairness, or performance evidence. No Distribution archive, upload,
processing, review submission, or Apple approval has occurred for this branch.
