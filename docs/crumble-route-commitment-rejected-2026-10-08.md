# Crumble Escape Commitment: Rejected Experiment

Parent: baa145e165dd9fa4c3d8ddae3c70009a9a35bfa7.
Experimental source: bf1b5f9830a224502cb0489fcfec2aa7e9b467da.
Branch: experiment/kras-crumble-route-commitment.

Hypothesis: repeated selection while standing on WARNING ground disrupts an
otherwise visible SOLID escape step. A probe with real grounded contact counted
11 route selections where commitment would select once. RED: 1071 assertions
passed, one failed. The experimental runtime removed the additional random
replanning condition for unsafe ground, retaining hidden/non-solid invalidation.
GREEN: 1072 assertions passed. This consumes different RNG draws and can affect
later seeded decisions; no claim of preserved random sequence is made.

The two natural samples used the same offsets, rotated baseline characters,
and paired difficulty seeds as their unchanged-parent evidence. Each contains
24 baseline matches, 16 paired difficulty matches and two mutator stress runs.
Both samples completed with exit 0, official Godot 4.7.1, matching start/end
experimental fingerprint 86ef3555e0efabf994a275e711c1a79b75249802a964dfc470ab49cafc4a87f8.
Both strict import-mode engine guards and both mutator runs passed.

| Offset | Parent seat wins | Experiment seat wins | Parent seat bias | Experiment seat bias | Parent Expert edge | Experiment Expert edge |
| --- | --- | --- | --- | --- | --- | --- |
| 1200000 | 8,4,12,0 | 4,4,3,13 | 0.25 | 0.291667 | 0.56875 | 0.55 |
| 1500000 | 6,9,5,4 | 3,10,5,6 | 0.125 | 0.166667 | 0.50625 | 0.525 |

The primary sample worsens seat bias and Expert edge. The independent sample's
small Expert gain does not qualify the regression. The primary report retains
spawn slot advantage; the independent report has no flags, but that alone is
not a release acceptance criterion. No thresholds were adjusted, no new seed
offset was selected to hide the unfavorable primary outcome.

Decision: REJECT. Runtime and experimental test-probe changes restored manually
to the exact parent bytes. git diff against the parent for both files is empty.
The restored ground-routing suite passes 1071 assertions and the strict
completed-test guard. The previously qualified full gate belongs to the
unchanged runtime/test parent, not the rejected experimental runtime. No new
full-game stability or device performance claim is attached to this experiment.

Logs: /tmp/kras-route-commitment-red.log,
/tmp/kras-route-commitment-green.log,
/tmp/kras-route-commitment-1200000.log,
/tmp/kras-route-commitment-1500000.log,
/tmp/kras-route-commitment-restored.log.

Raw experimental reports: docs/qa/crumble-route-commitment-2026-10-08/.
Parent reports: docs/qa/crumble-current-2026-10-08/.

Crumble balance remains unresolved. Future investigation must isolate route
quality, arrival braking and escape feasibility using actual floor/contact and
natural paired samples rather than treating every replan as a demonstrated bug.
No gameplay improvement, main merge, production change, iOS archive, App Store
upload, processing or App Review submission is claimed.
