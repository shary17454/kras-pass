# Tournament Results Layout

Branch: fix/kras-podium-results-layout.
Parent: 24f6499 on fix/kras-shared-pickup-observation.
UI/test commit: c11db5eeb016e6ac012d8c80f68e6367d96e59a9.

## Fix

The standings screen nested a gallery ScrollContainer inside Screen's own
ScrollContainer. At the end of a tournament, the podium and award labels
consumed most of the available height, leaving an incomplete standings row
inside a very short independent scrolling region.

Standings now use natural-height rows inside the existing screen scroll.
The champion summary and rows adapt to side-by-side landscape and stacked
portrait layouts. A bounded podium height leaves more space for standings.
Next/rematch/home actions are pinned in the screen column outside scrolling
content. Points, cups, rank calculation, tie handling, replay and session
transitions are unchanged. All four player rows are retained.

## Verification

- Existing party suite: 4171 assertions passed in 5.8 seconds; exit 0.
  /tmp/kras-podium-layout-party.stdout and .log.
- Rendered party QA: exit 0, PARTY VISUAL CHECK: 0 failures.
  /tmp/kras-podium-layout-visual.stdout and .log.
- Strict import, test and rendered runtime log guards: exit 0.
- git diff --check: exit 0.

The rendered checks cover Arabic/English, 1280x720 landscape and 540x960
portrait, menu routes, standings/podium and existing four-touch game probes.
New explicit assertions check all four rows, absence of the nested row
scroll, pinned actions within the viewport, adaptive champion orientation,
and complete unclipped landscape champion rows.

Before screenshots were preserved at /tmp/kras-podium-before and after
screenshots at /tmp/kras-podium-after. The Arabic landscape podium now
shows all four ranks together beside the summary. Portrait shows complete
first rows and allows the entire summary/standings content to scroll above
fixed actions; it does not promise all four ranks fit in the first viewport.

The initial isolated checkout import was stopped with exit143 while
rebuilding NotoSans font caches. Assets and project.godot were confirmed
unchanged from the parent. Only .godot/imported resource caches were copied
from the previously qualified checkout, not editor state or script caches.
The subsequent import completed with exit0 and passed its strict log guard.
This is cache reuse with unchanged inputs, not a completed initial import.

## Scope and Remaining Gates

This is an isolated UI branch, not a main merge or an App Store submission.
The original all-game campaign remains on immutable c5fa1f9. This UI change
does not alter game physics or AI, but a later integrated release must still
be qualified at its exact final source; do not label old-source campaign or
iOS-export hashes as this branch's release qualification.

Not covered here: extended names/large accessibility scales, native safe
areas, physical touch/gamepad usability, iPhone/iPad sustained performance,
four-player vehicle readability, every minigame orientation, production
Railway online acceptance, protected database backup/restore, release
promotion, new version/build, signed Distribution Archive, upload/processing
or App Review submission. The full requested goal remains incomplete.
