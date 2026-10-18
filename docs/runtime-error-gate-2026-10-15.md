# Runtime engine-error gate - 2026-10-15

## Defect

A new diagnostic run of `tests/balance_tank_trace.tscn` on the committed Oasis
source finished with process exit 0, but its engine log contained:

```
ERROR: Condition "ret != noErr" is true. Returning: ""
   at: get_system_ca_certificates (platform/macos/os_macos.mm:1035)
```

The previous log guard intentionally accepted this text in runtime mode. That
allowed a run with an engine error to be called clean. No certificate, Keychain,
TLS setting or production service was changed to suppress this error.

## Correction and tests

`tools/check_godot_log.sh` now rejects any `ERROR:` outside explicit `tests` mode.
Existing script/resource/leak failures remain fatal in every mode. Unit suites
retain their intentional failure injection and must still produce a positive
completed assertion summary. A passing test suite is not an error-free device run.
Ordinary `WARNING:` messages remain visible without being reclassified as errors.

Regression matrix covers runtime, balance, stability, compile and import modes,
including errors appended after an otherwise positive compile summary.

- Before guard change: 7 tests passed, 1 failed, proving the acceptance defect.
- After change: all 8 log-guard tests passed.
- All existing Node tool tests: 15 passed, 0 failed.
- Real diagnostic engine log: rejected with exit 1 by the corrected guard.
- Previous Oasis full-suite log in tests mode: passed the corrected guard.
- Previous Oasis compilation and both natural campaign logs: passed in their
  respective compile/runtime modes. Their gameplay was not rerun for this shell-only fix.

## Rejected diagnostic sample

Seed offset 99000000, 112 baseline + 56 difficulty + 2 smoke instances,
146.3 seconds, exit 0. This sample is NOT qualified balance/stability evidence
because of the engine error, regardless of completed match counts. Its reported
spawn and difficulty warnings remain unaccepted diagnostic observations, not a
new accepted performance comparison. No AI tuning was based on this sample.

The engine log and JSON/HTML output are preserved in the sibling directory
`../qualification-log-guard-2026-10-15/`. Private save contents were not copied.

No gameplay/AI behavior was changed. Expert difficulty remains unresolved.
Stage 0 remains QA_PENDING / MERGE_PENDING. No push, merge, Railway mutation,
Xcode Archive, upload or Apple review submission occurred.
