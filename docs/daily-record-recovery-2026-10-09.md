# Daily Record Recovery

Parent: `2aaa55ce24b2012fa3dc483ba0d885d5fa4980b3`.

Malformed saved daily records previously caused script errors in record lookup
and attempt creation. Lookup now normalizes a copy, without writing the save.
Attempt creation repairs only the addressed record. Valid progress, extension
metadata, unrelated records and existing reward claims remain intact. Counters
reject booleans, fractions, non-finite values and overflow; a saturated attempt
counter refuses a new attempt without rewriting progress.

The first repair incorrectly discarded valid completion counts when the
receipt field was absent. A failing regression exposed that error; the final
repair retains the count and conservatively reconstructs the receipt floor.
Neither repair changes the natural-completion and duplicate-reward gates.

Evidence in `/tmp`:

- `kras-daily-corrupt-before-20261009.log`: original malformed-record failure.
- `kras-daily-partial-before-20261009.log`: partial-progress regression, three failures.
- `kras-daily-partial-after-20261009.log`: 237 assertions pass.
- `kras-daily-corrupt-final-full-20261009.log`: 395328 assertions pass, 200.6 seconds.
- `kras-daily-final-compile-isolated-20261009.log`: 439 scripts compile.

The initial compile invocation omitted isolated test storage and logged sandbox
directory errors. It is not accepted as clean evidence. The isolated rerun
replaces it; raw diagnostics remain available. Final logs pass the strict guard.

Runtime fingerprint:
`53103b5201cf824c37fa0d6d222fe866c4074889f2be5393e5f7559121764b8c`.

Earlier native archives and CI balance/network artifacts do not prove this
source revision. The network tank-final failure remains unresolved. This
correction is not an archive, production deployment, upload or review submission.
