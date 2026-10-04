# Main menu exit confirmation

Based on `b6a45f7c10e4858566688cb561daaa151c845d9a`.

## Defect and change

The explicit Quit button requested confirmation, but root-level `go_back()`
flushed saves and called `SceneTree.quit()` immediately. Keyboard/controller
Back or Escape followed that unprotected path. Root back now uses the same
confirmation as explicit Quit. A single dialog is reused after cancellation,
so repeated requests do not accumulate modal nodes or duplicate callbacks.
The existing confirmed exit still flushes saves before quitting; cancel does
neither. Save formats and gameplay/network rules are unchanged.

The original source path was inspected directly. This is an independently
identified exit-protection defect, not a proven explanation for the prior
incomplete rendered preparation run documented in
`online-loading-handoff-2026-10-04.md`.

## Executed checks

- Exit fixture: 12 assertions passed headless, exit 0, 12.3 seconds.
  `/tmp/kras-menu-exit.log`.
- The same fixture with Metal Forward Mobile on Mac M5: 12 assertions passed,
  exit 0, 1.6 seconds. `/tmp/kras-menu-exit-rendered.log`.
- Rendered resource preparation and actual Main Menu -> Match -> Main Menu:
  737 assertions passed, exit 0, 6.6 seconds.
  `/tmp/kras-menu-exit-preparation-rendered.log`.
- Compilation: 343 scripts passed, exit 0.
  `/tmp/kras-menu-exit-compile.log`.
- Completed-run log guards and `git diff --check` passed.

The exit fixture observes the actual confirmation buttons and overrides only
the final quit action to keep the test runner alive. It covers root back,
explicit quit, repeated requests, cancel, reopen, one confirmed callback, and
modal destruction with the menu. It does not simulate every branded controller
or prove iOS lifecycle behavior. The prior unfinished run remains unfinished;
this is new passing evidence on this source, not a retroactive pass.

Full source-matched core/network qualification and physical-device/release
gates remain open. No main merge, Railway deploy, Distribution archive or
App Store submission is claimed by these checks.
