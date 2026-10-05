# Immutable Source Qualification Continuity

## Source and Scope

Production/main source: `d8c27001453f3fb45f56f630f3448a5e58403283`.
CI policy correction: `0c089c9a3a7c1274f966b03713e208ae80193304` on
`fix/kras-main-qualification-continuity`. Only the quality workflow differs
from the production source; no gameplay, input, scoring or protocol changed.
No automatic merge or Apple submission is part of this correction.

## Observed CI Interruption

Run `37351545156`, source `18778f06ff137401c868e44b3b38e6c0a0f694d4`,
completed core and nine network jobs successfully, but was cancelled before
the remaining thirty network jobs could finish. Its balance job was skipped.
The existing ref-based concurrency group cancelled in-progress main runs when
later pushes arrived. A partially successful matrix is not release acceptance.

Main and manual runs now group by source SHA and do not cancel running jobs.
PR revisions retain ref-based grouping and cancellation. The existing three-job
parallel limit, forty scenarios, assertions, timeouts and evidence artifacts
remain intact. This retains immutable-source evidence at the cost of allowing
older main matrices to consume runner capacity; it does not bypass account
capacity limits. GitHub can still replace pending runs sharing the same group,
so repeated requests for the same SHA should not be used as a monitoring loop.

Ruby's YAML parser verified the policy fields and forty scenarios. Both existing
Node race/lab budget tests passed, with zero failures or skips. `git diff --check`
passed. Local `actionlint` was unavailable; hosted workflow execution remains
the authoritative expression/runtime validation.

## Linux Zone Regression Is No Longer An Unresolved Baseline Failure

Job `111903710102` in run `37351545156` succeeded on Ubuntu 24.04 against
source `18778f0`. Read log: `/tmp/kras-187-zone-linux.log`.
Its ordinary and three-round tournament checks passed for both two and four
human-controlled engine processes. These peers are automated, not real people.

The retained seed `438683058` also passed for both peer counts:
two-peer scores `[5,0,0,2]`; four-peer scores `[25,0,0,0]`.
The four-peer clients observed 1088/1107/1107 world snapshots; host and one
client restored their identities. Reported server loop maximum was 22 ms.
This supersedes the earlier Linux failure only for that source/scenario.
It is not all-game balance or Internet latency evidence.

## Fresh Current-Source Four-Peer Check

Command: `GODOT_BIN=/opt/homebrew/bin/godot node network-smoke.js
--game=zone_hold --humans=4 --seed=438683058`.

This actual Godot/WebSocket process group completed with exit zero. All four
peers moved and agreed on scores `[25,0,0,0]`. Host and one client reconnected;
clients observed 1086/1107/1107 world snapshots.
Log: `/tmp/kras-d8-zone-four-peer.log`.
Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-Pz5TbM`.
The run started on d8's runtime with the uncommitted workflow-only correction;
the correction was committed while it ran. No game/test script changed.

This Mac loopback run does NOT qualify latency: reported loop maximum was
883 ms. The timing file retains twelve stalls; worst sampled interval delay
635.825 ms consumed 12.121 ms Node CPU. The worst input wall interval was
204.899 ms with 1.896 ms CPU, and snapshot 227.032 ms with 0.474 ms CPU.
These differences suggest scheduling/wall stalls, but do not identify a root
cause or prove the absence of server cost, network delay or device contention.

## Current Production and Remaining Gates

Railway deployment `dce71894-0cee-43d5-8877-1bb78d4499a4` is SUCCESS,
RUNNING, main, exact d8 commit, repository `shary17454/kras-pass`.
Effective health check is `/health`, timeout 100 seconds. Build logs explicitly
record `[1/1] Healthcheck succeeded!`; `/data` volume is READY.
Live health returned `ok=true`, `authentication_ready=true`,
`multiplayer_enabled=false`. Bounded fifty runtime log entries showed startup
and the existing Config-as-Code deprecation warning, not an application error.
No secret, database, infrastructure ownership or online-enable setting changed.

Run `37359341823` targets d8 and was queued at inspection, not passed.
Physical iPhone 16 Pro Max remained unavailable in a fresh read-only Xcode 27
device check. Simulated devices do not prove physical RAM/FPS/thermal/battery.
Full immutable-source network matrix, four real Internet users, all-game balance,
original-content polish, physical QA and exact-source Distribution archive,
upload, processing and review submission remain required. No goal completion
or Apple acceptance is claimed.
