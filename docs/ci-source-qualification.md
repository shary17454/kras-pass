# Linux core gate and source evidence

## Verified run

Run: https://github.com/shary17454/kras-pass/actions/runs/37096092911

Core job `111126253240` completed successfully on 2026-10-03. Its downloaded
artifact is retained locally at `/tmp/kras-ci-37096092911-core`. The artifact
name uses GitHub's PR merge commit, not the feature head:

- Merge checkout: `e6285139a9da33d559f6a147315dba76e0c6e1d6`.
- PR head: `eefbf7c59da03a342d4e1e4a23c078bf4df2255a`.
- API-confirmed merge parents: `0d51356a76033cb8ff136b6d698875aa4c4237ef`
  and the PR head above.
- API-confirmed merge tree and locally verified PR-head tree both equal
  `1cbac615568323804e02811fbfed9f0cc2866761`.

This proves the tested checkout has the same tracked tree as that feature
head. It does not prove a signed iOS archive, production deployment, or a
later main commit was built. Main `567c308e3e9d94acb977567a76106f1e6931b2e9`
adds documentation after this head; its independent CI must be checked.

## Artifact results

Evidence below is from the actual stdout files, not inferred assertion counts:

- `compile.stdout`: 322 scripts compiled using Godot 4.7.1.
- `inventory.stdout`: 360 resources, 21 autoloads, 27 routes, eight
  characters, zero inventory issues.
- `tests.stdout`: 21,032 assertions passed.
- `stability.stdout`: three cycles, 117 matches, zero failures.
- `kras-server-capture-tests.stdout`: 120 tests passed, zero failures,
  cancellations or skips, using six captures generated in this core job.
- The real race regression and six dedicated boss AI checks completed
  successfully as part of the same core step.
- No script/parse/test failure or resource/RID leak pattern was found in
  the downloaded stdout evidence. This is not a device memory benchmark.

At the last inspected snapshot, five separate network jobs had succeeded:
Ring Rumble, Goal Guard, Gem Grab, Star Rush and Zone Hold. Remaining network
jobs were still queued or running. Neither the core's success nor the artifact
proves all 39 real-peer scenarios completed.

## Evidence retention repair

The workflow previously retained only armed, siege and forge captures although
the server gate requires six. It now also retains dreadnought, sovereign and
colossus captures. A per-scenario `kras-qa-source.json` records checkout commit,
tree, intended head, event/ref, run/attempt and tracked changes. Only explicit
non-secret fields are recorded; no environment or credentials are dumped.

Local validation parsed the YAML, syntax-checked every embedded Bash block,
executed the new source-recording step against a temporary directory and
checked its parsed checkout commit/tree, scenario and tracked-change evidence.
`git diff --check` passed. These are workflow validation results, not a claim
that GitHub has already executed the changed workflow.

No production online activation, Railway deployment, Apple archive, upload,
processing or review submission is implied. Physical device QA, network
matrix completion and the other product requirements remain release gates.
