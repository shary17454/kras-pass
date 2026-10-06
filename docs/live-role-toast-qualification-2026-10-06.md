# Live role notification qualification

## Source and scope

- Runtime and test source: `f8cfc0774b85f3f5c00952fa67a847641ece6355`.
- Branch: `fix/kras-live-role-toast-layout`; parent `68933b4`.
- Main already contains the parent runtime via `32ce9e0c2945c43dddae95801bed2a2f5ef0f501`.
- No character, scoring, physics, network authority, save schema, entitlement, or Apple version changes.
- No automatic merge to main or App Store submission in this qualification.

## Changes

- EventBus has a keyed live-status notification alongside the existing ordinary notification signal.
- A real hunter change replaces the same `tag.hunter` message immediately; identical snapshots do not rebuild it.
- Clearing the hunter clears its message. Old expiry tweens are stopped before removing the old card.
- Role notifications use the same localized live banner as the HUD, including on network replicas.
- Notifications are positioned below the actual clock, banner, boss meter and player chip bounds, not a fixed 140-pixel offset.
- Notification text wraps within the safe horizontal width. Portrait objective text is placed below the notification stack.
- The rendered soak report records startup texture size, live reported texture sizes, live window sizes and actual saved image size separately.

## Focused evidence

- 81 assertions passed in `status_toast_hud`, covering Arabic/English, portrait/landscape, rapid role changes, identical snapshots, clearing state, bounded message count, header separation and objective separation.
- 387 scripts compile. Inventory: 428 resources, 21 autoloads, 27 routes, 8 characters, zero issues.
- Focused test and compile logs passed the existing runtime log guard. macOS sandbox CA enumeration warnings were present; they are environment warnings, not ignored GDScript failures.
- Logs: `/tmp/kras-toast-tests-final-engine.log`, `/tmp/kras-toast-final-compile.log`, `/tmp/kras-toast-inventory.log`.
- The first general-test process was deliberately terminated after a subsequent source edit. Its partial output is not a final-source pass.
- Final general tests completed successfully: 361055 assertions, terminal exit zero, runtime guard PASS. Log: `/tmp/kras-toast-final-full.log`; engine log: `/tmp/kras-toast-final-full-engine.log`.
- Final repeated-match check completed 39 games with zero failures, terminal exit zero, runtime guard PASS. Report: `/tmp/kras-toast-stability-save/stability.json`; log: `/tmp/kras-toast-stability.log`.
- Stability scope is four AI, 39 default arenas, shortened timed rounds, unchanged race laps; one cycle does not prove multi-cycle post-warmup memory growth. Nodes and signal connections returned to their per-match baselines. Settled tracked static memory after cache release was 441360121 bytes, still an open memory qualification issue.
- Runtime/test/data/tools/project files were unchanged from the cited source throughout both final runs, verified with `git diff --exit-code` before and after. This report is a later documentation-only addition.

## Rendered checks

These are real macOS Metal/mobile-renderer windows, not physical iPhone/iPad tests. Each ran four Expert bots for 13 live seconds (3-second warmup and 10-second measured interval). Both ran alongside headless tests; the timing is not an isolated performance benchmark.

- Portrait image: `/tmp/kras-toast-final-portrait.png`, 720 x 1280. Report: `/tmp/kras-toast-final-portrait.json`.
- Landscape image: `/tmp/kras-toast-final-landscape.png`, 1280 x 720. Report: `/tmp/kras-toast-final-landscape.json`.
- Both images were visually inspected: current hunter agrees with the live HUD banner, notifications are below player cards, and portrait objective text no longer intersects the notification.
- Both reports show completed duration and cleanup node count 50 -> 50; all four fighters travelled nonzero distance.
- Landscape reports live texture size 854 x 480 separately from the 1280 x 720 window and saved image. This distinction prevents claiming native render-resolution performance from a screenshot alone.
- Runtime log guards passed for both final rendered runs.
- Residual issues: portrait objective can still cover the upper edge of arena action; broad HUD density and camera framing need further polish. Frame spikes remain (371.6 ms portrait, 271.2 ms landscape), and retained static memory remains approximately 329/333 MiB. These observations do not prove a leak or its cause and are not fixed by this patch.
- The first sandbox native-render launch could not reach macOS display services and was stopped. Local elevated launches completed; that failed launch is not render evidence.

## Live external state

- Railway deployment `aaa08e44-2bd9-4e24-a984-ebcf4cf04bd9`: SUCCESS, GitHub `shary17454/kras-pass`, main `32ce9e0c2945c43dddae95801bed2a2f5ef0f501`.
- `/health`: `ok=true`, `authentication_ready=true`, `multiplayer_enabled=false`.
- Latest deployment-log snapshot contained six informational startup records and no errors. This is a bounded startup check, not long-term stability or complete database/auth qualification.
- Main GitHub workflow `37398510577` was queued when checked; no CI pass is claimed. Earlier main workflow `37394232632` was cancelled.
- New branch runtime is not deployed to Railway or included in an Apple archive. No production online activation, certificate import, archive, signing, upload, processing or review submission was performed here.

## Remaining release gates

- Integrate the reviewed patch only under the repository policy; current-source checks above do not replace complete release CI and physical QA.
- Continue remaining gameplay balance, fair AI perception and UI/camera polish; this patch does not make all 39 games READY.
- Complete physical iPhone/iPad orientation, input, long-session battery/thermal and frame-pacing checks.
- Complete production online qualification before enabling it.
- Freeze the final approved source, reconcile version/build against live App Store Connect, then separately prove archive, signing, upload, processing and review submission.
