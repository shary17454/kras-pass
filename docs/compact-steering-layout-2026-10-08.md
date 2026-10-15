# Compact Steering Controls

Repository: shary17454/kras-pass. Branch: fix/kras-compact-steering-layout.
Code commit: 8f5f98e4ace8fd9892799d7e203205d9f9c44cbf.
Parent: bd4f20977ec95e07fbaf5263056121e8feb78f4b.

## Verified Defect and Fix

Actual Metal screenshots of Scrap Karts showed tall driving pads occupying
34 percent of viewport height. The ordinary boost button overlapped a driving
pad, so button-first touch routing could steal steering touches in that area.

Steering pads now have width bounded by the configured action-button diameter
and height bounded by 20 percent of the control region. Single-player default
boost is above throttle with an 18-pixel gap, mirrored with the handedness
setting. Four-player action placement, saved custom action positions, ordinary
input bits, keyboard/gamepad routing and vehicle physics are unchanged.
Saved custom layouts are preserved, not forcibly rewritten; a user can still
manually place a custom button over another control.

## Evidence

- Before the fix: focused input-source suite, 328 passed and 18 failed.
  /tmp/kras-steering-layout-red.log. Failures cover overlap and pad height.
- After the fix: input-source suite, 438 assertions passed, exit zero.
  /tmp/kras-steering-layout-multitouch.log. Includes ordinary full-screen
  portrait/landscape and four-player region dimensions, both handedness modes,
  per-pad touch ownership and held throttle plus boost.
- Party suite: 4171 assertions passed, exit zero.
  /tmp/kras-steering-party.log. Its two unconfigured-online warnings are retained;
  this suite does not qualify production multiplayer.
- All 422 scripts compile. /tmp/kras-steering-compile.log.
- Four actual Metal captures per language for scrap_karts and kart_sprint,
  portrait 540x960 and landscape 1280x720, Arabic and English. Both runs exit zero
  with four captures and zero failures. Images manually inspected include Arabic
  Scrap Karts portrait, English Scrap Karts landscape and English Kart Sprint
  portrait; nonblank checks alone are not visual acceptance.
  /tmp/kras-compact-steering-ar/screenshots and
  /tmp/kras-compact-steering-en/screenshots.
- Strict Godot log guards passed on both test logs, compilation and both visual
  logs. git diff --check passed.

These checks ran on the candidate files before the code commit; that commit
preserved those exact files. They are not a full new all-game balance gate.

## Remaining Release Gates

The portrait arena is still small and needs separate camera/content polish.
This fix does not claim new graphics, larger arenas, all-map visual acceptance,
four-human device gameplay, battery/thermal performance or 39 READY games.
The in-flight all-game campaign on b8efc513 predates this UI source change and
cannot attest this child source's full fingerprint.

Live App Store Connect inspection showed 1.1.10 Build 107, Ready to Submit in
TestFlight and Ready for Distribution in Distribution, with no pending review
submission. Local Keychain inspection found the requested Apple Distribution
identity. Neither observation is a new Archive, upload or review submission.
No Xcode Cloud, P12 import, certificate change, main merge, production Railway
deployment, account export or database migration occurred.
