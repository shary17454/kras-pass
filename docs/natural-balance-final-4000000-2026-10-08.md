# Current-source natural campaign: final verification

Campaign `37770437501`, source commit
`0fee3c06229385f87f6141e16554e88a1cddee21`, seed offset `4000000`.
Simulation fingerprint:
`3c4a6722c287b7c486e51f875ee80350949c5fe06eaa37bf814f90e795bfb746`.
Engine: official Godot 4.7.1 stable. This is Linux gameplay QA, not Xcode Cloud.

## Independent verification

Downloaded all 39 natural-balance artifacts and the final CI summary. Ran
`tools/balance-report.mjs` without partial mode, requiring paired difficulty,
the exact source fingerprint, commit, run ID and seed offset. Recalculated
summary is deep-equal to the downloaded CI summary. All 117 import, policy
and simulation logs pass `tools/check_godot_log.sh` (strict import mode for
import logs). The clean checkout at `f48c226b00b4fb8c74b9b3a3112726337af2cb02`
has the same simulation fingerprint; this does not prove a native archive.

- 39/39 games complete; 1638 matches complete.
- 936 baseline matches, 624 mirrored difficulty matches, 78 stress matches.
- All mirrored pairs verify matching seeds and characters with exchanged
  expert slots. No missing evidence or source mismatch was found.

## Remaining warnings

Two games retain `expert bots no better than easy`:

| Game | Expert edge | Baseline seat bias | Character bias |
| --- | ---: | ---: | ---: |
| blast_ball | 0.48125 | 0.1666667 | 0.0416667 |
| scrap_karts | 0.50625 | 0.0416667 | 0.125 |

These samples do not establish causation or a difficulty fix. The earlier
Blast Ball held-out value of 0.525 does not override the current warning.
Historical campaign warnings and Sweeper character-balance evidence remain
relevant; no threshold or simulation policy was relaxed to pass this run.

## Boss objective outcomes

Baseline defeated/survived counts are Colossus 18/6, Dreadnought 24/0,
Forge 24/0 and Sovereign 23/1. All four mirrored difficulty cohorts defeated
their boss in 16/16 matches. Seven of eight stress matches ended in survival,
not defeat; only Dreadnought chaos ended in defeat. A completed match is not
evidence that the boss objective was achieved.

## Release boundary

`balanceReviewComplete` and `releaseReady` remain false. Device performance,
native visuals and controls, Internet multiplayer/reconnect, production
integration, current-source signing/archive, and App Store submission require
separate acceptance. Loopback peer tests are not Internet/device tests.
No main merge, Railway promotion, archive, upload, or review submission is
proved by this campaign. Do not market all 39 games as READY from these logs.

Retained local artifacts:
`../qualification-4000000-current` and
`../qualification-4000000-summary/balance-summary.json`, relative to the
repository checkout's parent workspace. Test-save directories are not
committed because they may contain ephemeral session data.
