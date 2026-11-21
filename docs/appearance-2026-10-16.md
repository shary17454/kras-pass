# Appearance support - 2026-10-16

## Behaviour

Settings now expose localized System / Light / Dark choices. Existing saves
receive `appearance: system` through the settings defaults merge; no progress
schema is replaced or reset. Invalid stored choices fall back to system.
Explicit choices persist through SaveSystem. The selector updates in place.

UITheme resolves the device preference at startup, listens for the native
system-theme callback, and refreshes on application focus. Unsupported/headless
display servers retain the previous dark appearance as a deterministic fallback.
Explicit light/dark selections take precedence over the device preference.
There is no polling timer and no per-frame theme-tree traversal.

The shared UIKit palette supplies both appearances. UITheme updates global
form/pop-up styles and existing overrides without rebuilding menu or match
instances. Style resources retain semantic surface information, including glass
and character-tinted surfaces. Player identity colours, cosmetic data and arena
lighting are not changed. Timer and round labels receive themed backings so
their contrast does not depend on the 3D sky. Touch steering surfaces use the
active palette; coloured fire/action buttons keep their contrasting white ink.
Radar and offscreen player markers also follow the active surface/text palette.
Legacy 3D art references in seven minigames now use immutable MeshFactory world
colours with their exact original values, not mutable interface accents.

RTL OptionButton mirrored states are explicitly styled. This was discovered
through real rendered screenshots, not merely a successful build.

## Validation Scope

The appearance suite covers all 26 non-match router entries in Arabic/English,
portrait/landscape and light/dark: 208 UI states. It also checks live switching,
persistence, invalid choices, actual display preference resolution, high-contrast
interaction, popup/input inheritance, contrast ratios and unchanged match
identity/phase/player colours. The visual smoke selection covers Settings,
Game Library, Characters and Touch Layout in the same matrix, plus two live
HUD images. Light tinted cards and secondary text have an explicit contrast
regression; cosmetic swatches are exempt from palette remapping.

Final headless results (strict log guards and process exits passed):

| Check | Result |
| --- | --- |
| Compile | 468 scripts |
| Appearance / all 208 UI states | 1,151 assertions |
| Final Metal visual smoke / 34 screenshots | 627 assertions |
| Round announcements | 6,339 assertions |
| Player name fitting | 3,585 assertions |
| HUD numeric fitting | 1,569 assertions |

The preceding integration campaign passed 31,951 assertions including real
routed tournaments, daily flow, save handling, bundled fonts, input sources,
party touch and system services. Later indicator/touch checks passed 85
offscreen-cue assertions, 97 radar-layout assertions and 17,155 party-touch
assertions. The last changes only polish shared surface/text rendering; the
affected text-fit suites above were rerun afterwards. These are distinct
campaigns, not a claim that a new full gameplay suite was run.

The final gallery inspection also exposed an existing selectable-card wrapper
that ignored its content minimum size. The wrapper now propagates that size;
the 1,151-assertion matrix includes card containment and pairwise non-overlap
checks across both themes, languages and orientations. Final light/dark gallery,
settings, touch-layout and HUD screenshots were inspected after this fix.

Final selected source fingerprint:
`27feb3b52380f75b29156edd2c20dfd6be0e9e65eac2d33ec92a9299c20d8e8b`.
The evidence compares 1,007 base tracked source/test files, records the 20
changed files plus the new appearance suite, and verifies their bytes match the
workspace. This is not a Git commit or signed archive attestation.

Native captures use Godot 4.7.1 / Metal Forward Mobile on the Mac, not an iPhone.
An early full native campaign produced 210 captures before the final RTL/HUD
polish. A subsequent campaign stalled at 130 captures and was interrupted;
its exit code alone is NOT accepted as a completed test. The capture fixture
now uses a test-only explicit draw instead of an unbounded frame_post_draw
wait, and compares rendered screen-background pixels with the active palette
to reject stale-theme frames.

An intermediate headless campaign hit its 300-second process deadline without
a positive completion summary and was rejected. Default-theme updates now
batch resource notifications, and unchanged colour overrides are not reassigned.
The subsequent 208-state campaign completed successfully. This is not a device
FPS, battery or thermal benchmark.

Final test summaries and synthetic logs are preserved outside the repository
in `qualification-appearance-2026-10-16/`. Device-only OS appearance callbacks,
physical touch and iPhone/iPad display behaviour still require hardware QA.
The previous full-suite count of 445,263 belongs to the earlier touch fix,
not to this appearance change.

## Git / Distribution

Work began on clean `feature/kras-online-random-rotation`, last verified commit
`c8a9be4c3666c1c9e259a90f1ddbc4a92c4c639a` in the private kras-pass checkout.
Later Git reads blocked: `.git/HEAD` was reported hidden, compressed, dataless.
Read attempts were stopped; no Git metadata was recreated, no history was
rewritten, and no push, merge, deployment, archive or App Store action was made.

## API References

- [Godot DisplayServer system theme callback](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-set-system-theme-change-callback)
- [Godot OptionButton theme states](https://docs.godotengine.org/en/4.2/classes/class_optionbutton.html#theme-properties)
