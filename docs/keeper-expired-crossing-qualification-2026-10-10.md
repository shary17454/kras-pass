# Keeper Expired Crossing Qualification

## Defect And Fix

Incoming-ball arrival was computed from a delayed visible sample but compared
only against zero. A ball predicted to have already crossed the keeper's
contact plane during the observation delay could displace an upcoming save.

Selection now compares arrival against the nonnegative age of that sample.
It uses the existing observed trajectory, not private velocity or current hidden
state. Movement, ball physics, character stats, timers, scoring and difficulty
profiles are unchanged. A fresh imminent crossing remains eligible.

The new regression failed eight checks before implementation, covering all four
court sides at low and high prediction. After the fix and fresh-sample boundary
coverage, all 53 assertions passed. Existing delayed-motion, visibility and
personal travel-budget checks remain enabled.

## Source And Regression

Parent commit: `5038d17953c0011b47cbfab87f7099e309227174`.
Tests ran sequentially in `/tmp/kras-tank-pursuit-check`, with the two modified
files copied from the checkout and byte-compared after testing.

- Full regression: 406955 assertions, exit 0, 333.0 seconds wall time.
- Compile check: 448 scripts, exit 0.
- Strict completed-test/error/leak log checks passed.
- `git diff --check` passed.

Runtime fingerprints matched start/end for each report:
before `76e256d502b981e4b3047d73dd7c015912f779aa08e77a3f298990252f63e4b6`;
after `87864f3ec75cfa8f3722f5001cf9372d7872bc589c83e632889131af1c29377a`.

## Natural Comparison

| Sample | Baseline matches | Difficulty matches | Expert edge | Slot bias | Flags |
| --- | --- | --- | --- | --- | --- |
| Before, offset 10100000, adjacent roster | 24 | 16 | 0.5192 | 0.2500 | spawn advantage; expert no better than easy |
| After, same cohort | 24 | 16 | 0.5337 | 0.1250 | none |
| Before, offset 13100000, balanced roster | 96 | 48 | 0.5272 | 0.0208 | none |
| After, same independent cohort | 96 | 48 | 0.5288 | 0.0833 | none |

All 240 baseline and 128 difficulty matches completed, as did eight mutator
matches: 376 comparison matches total. All four runtime logs passed strict
checks. Each cohort used identical seeds and roster policy before/after.

Expert improvement is modest, and independent-cohort slot bias increased while
remaining below the automated threshold. Neither missing flags nor this
specific regression proves full balance or playtest acceptance. Preserve the
earlier warnings; the larger before sample did not reproduce its small-sample
spawn imbalance. No acceptance threshold was changed.

Evidence: `../qualification-keeper-expired-crossing-2026-10-10/`, including the
initial failing test and all before/after reports.

## Separate Earlier-Source CI

Core run 37995167985 succeeded at d1921de, before this keeper change.
Tank run 37995611795 succeeded at parent 5038d17. Downloaded evidence contains
one matching clean source attestation, 22 strict-clean engine logs, 22 completed
peer reports and 34 recorded round-history entries. Results match within each
of seven distinct two-/four-player groups. Different player-count groups are
separate matches and must not be compared to each other.

This successful tank campaign does not erase the prior missing-damage failure
or prove current-source all-game networking. Current balance/network campaigns,
remaining product/content work, device/controller/performance QA, production
approval and a new exact-source signed archive remain open. No main promotion,
production deployment, Apple upload or review submission occurred here.
