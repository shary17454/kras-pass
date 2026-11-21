# In-world player identity symbols

Each Fighter now has the same unique slot symbol as PlayerConfig, the HUD and
touch controls. The symbol uses the bundled UI font, a dark outline and a
camera-facing Label3D. It remains depth-tested, inherits player/marker visibility,
and does not change movement, collision, character stats or match scoring.

Shared arena cameras use pixel_size 0.025; closer personal vehicle cameras use
0.005. The initial shared size was visibly excessive in vehicle views and was
corrected after inspecting actual Metal screenshots, not merely the automated
layout result. This is a bounded world-space label, not a constant-pixel overlay.

Regression coverage checks all four distinct symbols, shared HUD identity,
depth testing, font availability, hide/restore behavior and compact driving size.
All 430 scripts compile. Eight rendered four-human Arabic captures cover
Goal Guard, Colossus, Tank Arena and Rocket Race, in both orientations. Their
automated visual checks and strict runtime log guards passed. Four captures
were additionally inspected manually; this does not certify every map or device.

Evidence directory outside the repository:
`../qualification-player-symbols-2026-10-08/`.

The final full suite passed 392722 assertions in 176.7 seconds, exit 0. Its
strict test-log guard passed. The first full run
was deliberately stopped because fixed-fps was omitted; it is not passing
evidence. The final run uses fixed-fps 60 and an isolated save root.

This change does not resolve the remaining natural-balance flags, physical iPhone
QA, production promotion, signing/export, upload or App Review submission gates.
It does not enlarge the small shared-camera character models themselves.
