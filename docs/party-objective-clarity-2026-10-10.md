# Party objective clarity qualification - 2026-10-10

## Scope and source

Based on `72b6a0da2769395b94a3944887a317bc4631dd96` on
`feature/kras-online-random-rotation`. This batch changes 31 existing
`game.*.desc` values in each of Arabic and English. Keys and other values are
unchanged. Rules, scoring, physics, character stats and AI are unchanged.

The descriptions now state short, actionable goals. The visual fixture checks
the localized objective and, when visible, its viewport bounds and absence of
intersection with player cards and actual touch controls. Hidden vehicle-view
objectives are recorded as hidden, not treated as visibly inspected.

## Candidate checks

- Content/localization unit: 121 assertions passed.
- Visual roster policy: 182 assertions passed.
- Compile check: all 448 scripts compiled.
- English graphical run: 78/78 captures passed.
- Arabic first graphical run: 76/78 passed; Ring Rumble landscape and Magnet
  Court portrait were paused with the pause menu present after desktop focus
  loss. Objective checks themselves passed. The complete run remains failed.
- Arabic exact affected-game retry: 4/4 passed, without changing the fixture,
  source, pause behavior or acceptance criteria.
- Composite coverage: 156 unique game/orientation/language cases; 160 attempted
  captures, 158 successful captures including two duplicate retry cases.
- Strict Godot log guards passed for the successful candidate runs.

Graphical checks use four touch sources, one default arena per game, 1280x720
and 540x960 desktop viewports, Metal mobile rendering and two seconds of live
play. They are not completed four-human matches or physical iPhone/iPad QA.
Manual inspection covered Arabic Forge landscape and Crumble portrait,
English Forge landscape and Crumble portrait, and the two paused Arabic
failure images. Do not claim all screenshots were manually reviewed.

## Independent prior-source evidence

Core CI run `38000048347` succeeded on committed `72b6a0d`: its source
attestation matches the full hash above, feature ref and clean tracked state.
The artifact reports 406980 assertions and 117 stability matches with zero
failures. This is prior-source evidence, not a full-suite result for this batch.

Tag Hunt natural expanded cohort on that prior source completed 146 matches:
96 baseline, 48 difficulty and two stress cases. It reports no balance flags,
character bias 0.05681818, slot bias 0.01262626 and expert edge 0.621242485.
Runtime fingerprint was
`2bcfc4b9d2af0f5d7aac6829a8788c7876e26a9ab3e264722489bd00a6bf12ee`.
No Tag Hunt runtime tuning was applied from this sample. One cohort does not
establish universal balance or READY status.

## Evidence and remaining gates

Local evidence is retained outside Git at
`../qualification-party-objectives-2026-10-10/`, including original failed
Arabic captures, retry captures, English captures, content/roster/compile logs,
the Tag Hunt report and downloaded prior-source core artifact.

Stage-zero QA and merge gates remain open. Full current-source CI, all-arena
and physical-device acceptance, production database qualification and final
release-source archive are not established by this batch. No main merge,
Railway production deployment, Apple upload or review submission is included.
