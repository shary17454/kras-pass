# iOS export privacy-policy gate - 2026-10-15

Status: local release-tool correction, not an Archive or Apple privacy approval.

## Finding and correction

The source export preset currently leaves camera/microphone/photo usage text
empty, disables tracking and disables exposing local save files. Read-only
inspection of the existing generated Info.plist, privacy manifest and entitlements
also passes those policy checks. Those generated files are not proved to contain
the current application source and are not a new release archive.

The existing export attestation hashed generated files but did not enforce these
project requirements. A deliberately re-stamped fixture with unwanted permissions,
tracking or document exposure could therefore pass verification. The baseline
ran 20 tests and failed 15 subtests across three new policy test groups.

tools/ios_export_evidence.py now requires the generated application Info.plist,
PrivacyInfo.xcprivacy and entitlements alongside the game pack/project/libraries.
It parses them using plistlib and checks:

- No camera, microphone, photo read/write, contacts, location or ATT usage keys.
- No local Documents file sharing or open-in-place enabled by the app plist.
- Explicit tracking=false, no tracking domains, and no collected-data entry
  marked for tracking; malformed types are rejected rather than coerced.
- No enabled sensitive camera/audio/contact/location/photo entitlements.
  Harmless explicit false values and existing Sign in with Apple are retained.
- Missing, malformed and non-dictionary policy documents fail closed.

The policy runs both when reusing an export and before recording a fresh stamp.
The existing ci_scripts/export_current_ios.sh already calls both paths, so no
alternate release route or new flag is required. A failed record attempt leaves
the existing stamp unchanged. Evidence schema format remains version 1; the
changed tracked tooling input requires a fresh export under the existing source
identity check. File hashes alone do not override the policy.

## Verification

- Final Python suite: 24 tests passed, exit 0, 11.673 seconds.
- All Node tool tests: 15 passed, 0 failed.
- bash -n tools/export_ios.sh ci_scripts/export_current_ios.sh: exit 0.
- Existing generated export's three policy documents: privacy_valid=True,
  read-only inspection only, not full source/export/signature verification.
- git diff --check: passed.

One expanded fixture initially attempted to encode None in an XML plist, which
plistlib cannot represent. Replaced that fixture with a representable non-dict
entry to exercise the intended malformed-data case. A one-off inspection command
also had an unmatched parenthesis; the corrected read-only command passed. Neither
was accepted as qualification before correction.

The CLI regression proves both rejection without stamp overwrite and successful
record/verify with policy-compliant fixture documents. Existing source-freeze,
cache integrity, manual Distribution identity and build-number tests remain.

## Limits

This enforces KRAS PASS's stated permissions/tracking policy, not complete Apple
manifest legality, required-reason accuracy, App Store Connect disclosures, SDK
behavior, permission prompts on a real device or a signed app's contents. The
legitimate optional account UserID declaration is not removed. No account data,
production service, signing certificate, profile, P12 or password was accessed or
changed. No usage permission was removed from a functioning feature.

This stage changed only Python release tooling/tests, not runtime gameplay or
GDScript. The previous gameplay fingerprint 42a6f remains unchanged; the prior
427673 Godot checks were not rerun or counted as a new run here. The source-export
identity separately includes tools/ and will change with this release-tool edit.
Completion-tail output is retained at the sibling directory
../qualification-ios-privacy-gate-2026-10-15/python-unit-tail.log.

Stage 0 remains QA_PENDING / MERGE_PENDING. Device, balance, production rollout,
exact-source signed Xcode Archive, upload and review gates remain open.
No Git push, main merge, Railway mutation, Archive or Apple submission occurred.
