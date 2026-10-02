# Kras Pass App Store Readiness

This is a draft, not the live App Store listing or release approval. The
registry currently contains 39 minigame definitions; definition count alone is
not evidence that every game is release-ready. Confirm the shipping selection,
device QA and signed build before publishing copy or screenshots. Online play
is a development beta and must not be advertised as a released feature yet.

## Listing Copy

### Arabic

**Name:** كراس باس

**Subtitle:** كأس ألعاب مصغرة سريع ومجنون

**Promotional text:** تحديات قصيرة، شخصيات متوازنة، بطولات محلية، وطور حفلات سريع للاعبين على نفس الجهاز.

**Description:**
كراس باس لعبة حفلات ومنافسات مصغرة مبنية حول جولات قصيرة وواضحة. اختر شخصيتك، ادخل بطولة، وتنافس في مجموعة ألعاب متنوعة تجمع السرعة، التركيز، الحركة، والنجاة.

اللعبة تقدم تحديات مصغرة متنوعة، 8 شخصيات، ساحات متعددة، منافسين بالذكاء الاصطناعي، إعادة مشاهدة للمباريات، وتحديات يومية. كل شيء مصمم ليكون سريع الدخول، مناسبًا للعب المحلي، ومفهومًا من أول جولة.

**Keywords:** ألعاب,حفلات,بطولة,محلي,منافسة,عربي,مصغرة,تحديات,كأس

### English

**Name:** Kras Pass

**Subtitle:** Fast chaotic mini-game cups

**Promotional text:** Short challenges, original characters, local tournaments, and quick party play on one device.

**Description:**
Kras Pass is an original party game built around short competitive mini-games. Pick a character, start a cup, and jump through fast rounds of movement, timing, survival, memory, racing, and light combat.

The game includes varied mini-games, 8 characters, multiple arenas, AI opponents, replay playback, daily challenges, and Arabic/English localization. It is designed for quick sessions, local play, and clear rules from the first round.

**Keywords:** party,mini-games,cup,local,competition,arcade,Arabic,tournament

## Screenshot Plan

Capture these in landscape for iPhone and iPad:

1. Main menu with Arabic UI visible.
2. Tournament setup showing party presets.
3. A busy arena during live gameplay.
4. A different mini-game with clear scoring HUD.
5. Results or standings screen after a cup.

Marketing order: gameplay first, then presets, then roster/progression. Avoid screenshots that are mostly menus unless they show a clear feature.

## Human Playtesting Script

Minimum pass before App Store submission:

1. Two players, 20 minutes, Arabic UI, quick play and tournament.
2. One solo player, 20 minutes, English UI, adventure and training.
3. One iPad run, 15 minutes, check touch controls and text scale.
4. One interruption run: start match, background app, return, verify pause/save behavior.
5. One replay run: finish match, open replay library, replay the last match.

Record:

- Any unclear rule or objective.
- Any UI text that is clipped or hard to read.
- Any match that feels too long, too random, or unwinnable.
- Any crash, freeze, audio issue, or lost progress.

## Release Gates

- Godot compile check passes.
- Full headless test suite passes.
- iPhoneOS Xcode build passes without signing.
- Signed archive succeeds in Xcode with the Apple Developer account.
- At least one physical iPhone or iPad run is completed.
- App Store screenshots are captured from a real run or approved simulator run.
- The final source commit, Bundle ID, version and build are verified against
  the actual signed archive; record upload, processing and review separately.
- The listing describes only content verified in that build. Development-beta
  networking and debug fixtures must not appear as production capabilities or
  App Store gameplay screenshots.
