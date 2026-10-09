# Isolated Party UI Captures

Base source: c42ec46; gameplay fingerprint unchanged from b61e4b4:
`c35bd3679f7c9ae4b2efa01f92af3470237b84028f49da1e8e258dfcb7e95093`.

`tests/party_visual_check.gd` no longer overwrites fixed `/tmp/kras-party-`
filenames. Captures belong to the isolated test storage root's `screenshots/`
directory. Directory creation and PNG write errors fail the check rather
than silently leaving missing or stale evidence. No shipping gameplay,
save format or UI layout changed.

Godot 4.7.1 real renderer execution completed with exit 0 and zero failures.
The strict Godot log checker passed. Fifty PNGs were independently opened
by ImageMagick: 25 landscape 1280x720 and 25 portrait 540x960 captures.
Arabic portrait UI contact sheet was visually inspected.

Scope: eight menus in Arabic and English, both orientations; newer-save
compatibility notice, standings and podium in both locales/orientations;
four-touch shared arena, tank and armed race views in both orientations.
Checks include horizontal bounds, standings structure and pinned actions,
nonblank images, warning localization, HUD/control separation and vehicle
player projection inside each personal view. Vehicle captures are in
countdown, not a sustained gameplay or performance test. Scrollable
content and real-device touch ergonomics still require manual acceptance.

Raw outputs were preserved outside the checkout:
`../qualification-party-ui-isolated-2026-10-09/`.
Temporary original root: `/tmp/kras-party-ui-current-isolated/`.
Log: `/tmp/kras-party-ui-current-isolated.stdout`.

Neither the previously completed core CI nor the currently running network
and balance campaigns are claimed to test this changed QA script. They
retain their captured b61e4b4 source. No main merge, Railway deployment,
native archive, upload or review submission occurred.
