# Duel contact budget and qualification guard - 2026-10-10

## Source and scope

Parent `fe189a74a6f835e6231734ce2669a7473d92a7f5`, initially clean,
`feature/kras-online-random-rotation`. Godot `4.7.1-stable (official)`.
The new gameplay fingerprint is
`b97e86741b7e6a19a8b3eff113c376036abf342e1a1e6b79bb5e03ed50b23fa3`.
Source/test files are byte-identical between checkout and imported runtime.
Fingerprinting excludes most assets, tests, shell/JS helpers and native outputs;
test, guard and workflow hashes are recorded separately.

The source observation command began before the full suite and completed early
during its frozen run. This is explicitly not a completed pre-launch snapshot.
Source comparison after the full suite and before/after network qualification
found no drift. The network source snapshot completed before network launch.
No source, test, tool, data or scene edits occurred during a live campaign.

## Controlled experiment and design correction

The independent equal-pair sample at source 84d still reported character
advantage. The contact experiment therefore isolates the mechanics rather than
changing acceptance thresholds or global character stats.

The new Duel contact rule uses character power for outgoing strength and
character weight for incoming resistance. It does not additionally multiply
outgoing collision strength by the character resistance ratio. Power-up mass,
push modifiers, damage accumulation, dash and incoming resistance still apply.
This is a scoped balance-design correction, not proof of the sole cause of
the observed win-rate warning.

`Fighter.ram_character_mass_enabled` defaults to true, retaining the existing
contact equation in other games. Only Duel configures it false. Fresh fighters
are constructed per match; no save format, character IDs, RPC/schema, input,
geometry or global stats change is introduced.

The actual Fighter contact method is exercised for all 64 directed character
pairs, damage 0/40/100, closing speed 4.5/8/12, dash on/off and modifiers
on/off, in both real Duel and Ring match contexts: 4,608 measurements.
These cases directly invoke contact resolution, not a whole-match or physical
approach simulation; they cannot alone establish balanced win rates.

- Before candidate: 8,066 assertions pass, 1,152 fail, terminal exit 1.
  Failures are the proposed Duel contact contract, not script/parse failures.
- After candidate: 9,218 assertions pass, terminal exit 0, 2.7 seconds.
- Ring's entire measured matrix is byte-for-byte identical before/after.
- At speed 8, zero damage, no dash/modifier: Sakhra to Barq impulse changes
  4.4869943 -> 3.7551413; the inverse changes 2.3842716 -> 2.8489511.
  Power/resistance differences remain; characters are not made identical.

The initial fixture attempt had type-inference errors; the next had an
unsupported formatting token. Both were fixed before the valid red run, and
their raw logs remain preserved separately, not presented as valid failures.

## Qualification results

- Fresh full Godot suite: 419,373 assertions, exit 0, 693.4 seconds.
- Fresh successful compile: 456 scripts, exit 0, completed success summary.
- Controlled, full and compile stdout/engine logs: six stricter guard passes.
- Local four-client Duel WebSocket test: parent exit 0; four distinct player
  IDs, all moved, identical scores `[21, 14, 3, 4]`; IDs 1 and 2 reconnect.
- Eight network peer logs pass the stricter guard.
- Server comparison: 67 files, SHA-256
  `072ca4c1630d5d72a049c007c7feb068082635f28c141bc2be5b79a9489e8d4f`.
- Cumulative client frame gaps: 530/521/517/522 ms; server loop maximum 35 ms.
  Gaps include loading/transitions and are not a steady-state device FPS claim.
- Network fixture uses synthetic human inputs and a shortened round; it is
  not production Online, a full tournament or physical multiplayer acceptance.

## Guard defect fixed

An attempted compile command used `tools/compile_check.tscn`, which does not
exist. Godot returned exit 0 with `Failed loading resource/scene` messages;
the old runtime guard missed this spelling. This attempt is retained as a
failed invocation, never as successful compilation. The corrected command
uses `tests/compile_check.tscn`.

The guard now rejects both loading-failure spellings, and compile mode requires
a positive script count plus a completed compile success summary. Existing
test-summary and import checks remain intact. Runtime still permits deliberate
test error injections and the known platform certificate warning; it does not
blanket-ignore fatal diagnostics.

New guard tests fail 3/6 before the fix. Afterward, all 13 tests pass across the
new six guard cases and the existing iOS export/simulator guards. The previously
misclassified actual log now fails the guard. Shell syntax and workflow YAML
parse checks pass. CI is configured to run the new cases, but no remote CI run
is claimed because nothing was pushed.

## Evidence and next gates

Raw evidence is outside Git: `../qualification-duel-contact-2026-10-10/` holds
all initial/red/green/compile/full logs, both contact matrices, guard logs,
network raw files, source observations and `qualification-summary.json`.
Raw log/matrix copies were compared byte-for-byte.

One optional-lock Git diff refresh timed out while writing index metadata.
Its process terminated, lock absence was verified, and subsequent read-only
Git inspections used `--no-optional-locks`; no lock was deleted or work reverted.

Required next: natural 112-match pair-balanced comparison on the previously
warning-bearing 92000000 seeds, then independent 96000000 seeds. The first is
a matched diagnostic, not fresh held-out evidence after choosing this rule.
Historical 84d warnings remain recorded; no current candidate win-rate sample
exists yet. Do not mark Duel or all 39 games READY based on contact assertions.

Stage 0 stays QA_PENDING / MERGE_PENDING. No main push/merge, Railway deploy or
migration, new Archive, upload or App Review submission occurred. Production
backup/restore approval and device/quality acceptance remain unresolved.
