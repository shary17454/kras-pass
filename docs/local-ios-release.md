# Local iOS release

This pipeline uses local Xcode 27 or newer. The current workstation is expected
to use Xcode 27.2 at `/Applications/Xcode-27.app`. The scripts default
`DEVELOPER_DIR` to that application's `Contents/Developer`; they do not change
the system-wide `xcode-select` setting. iPhoneOS SDK 27+ and minimum iOS 18.0
are required. `REQUIRED_IOS_SDK` can raise, but cannot lower, the SDK floor.

## Scope and safety

- Export/compilation and signed archiving are separate operations.
- No signing, Keychain inspection, upload, automatic provisioning updates,
  production changes, or store submission occurs during the lightweight tests.
- The archive script requires `--sign`; running it is a separate authorized
  operation, not part of testing these changes.
- Disk guards run before generators or signing: export defaults to 8 GiB free
  on the source, output and log volumes; archive defaults to 12 GiB on its
  destination volume. More may be needed for GPU texture import and native work.
  Explicit overrides are `KRAS_IOS_EXPORT_MIN_FREE_GB` and
  `KRAS_IOS_MIN_FREE_GB` respectively. Both accept only finite positive GiB
  values, never zero/negative/NaN/infinity. Lowering a threshold accepts a risk
  of ENOSPC; it does not reserve space or prove sufficient capacity. At 118 MiB
  free, do not run either operation. No user caches are deleted automatically.
- Do not run concurrent exports against one checkout. Godot temporarily writes
  an addon and updates its import cache. Existing runtime export files are not
  overwritten; temporary files are removed before source attestation.

## Prepare committed inputs

The owner must finish integration and commit release inputs before exporting.
These scripts never commit or push. `ios_export_evidence.py` is reused unchanged:
it refuses dirty or untracked release inputs, including tools and native files,
and binds outputs to commit, tree and input hashes. Documentation changes alone
are not part of that helper's release-input identity.

The preset must already specify minimum iOS 18.0. This work does not modify
`export_presets.cfg` or native code/binaries. Supply a compatible, committed
Apple bridge and Godot templates first; no bridge rebuild is performed here.
Hashes attest the bridge bytes, not that they were rebuilt from that commit.
Native dependency deployment compatibility still needs release qualification.
The exported arm64 bridge must byte-match the current source checkout's bridge;
this does not prove that the checked-in bridge was rebuilt from native sources.

## Export or compile without signing

```sh
bash tools/export_ios.sh project
bash tools/export_ios.sh device
bash tools/export_ios.sh simulator
```

Each invocation exports into a fresh directory, records and verifies the source
stamp, and prints the evidence directory. Optional `KRAS_IOS_EXPORT_OUT` and
`KRAS_IOS_LOG_DIR` must name empty, non-overlapping directories. Logs, source
identity and toolchain details are isolated per run. Keep the printed paths.

`project` does not compile. Device/simulator compilation disables signing;
it checks the built app's plist and Mach-O minimum OS, and SDK version.
Simulator architecture checks and strict Godot-log checks remain enabled.
Compilation is not proof of runtime, device, multiplayer or store readiness.

The generated launch storyboard uses adaptive `systemBackgroundColor`, with
trait collections enabled and no forced appearance. Export removes the generated
`UIUserInterfaceStyle` override and rejects a missing launch storyboard. The
system color is compatible with iOS 18 without newer UIKit appearance APIs.
Archive validation also rejects a forced style or missing compiled storyboard.
This qualifies launch-screen configuration only, not application-wide dark mode;
both appearances still require visual validation on a device/simulator later.

Export rejects missing/empty icon catalogs or referenced icon files and checks
both device families and every supported orientation. Archive checks repeat
device/orientation coverage and require primary icons for iPhone/iPad plus the
compiled asset catalog. These are structural checks, not visual icon approval.
The privacy patch preserves required-reason API declarations, validates their
structure and merges the linked, non-tracking UserID/AppFunctionality entry
idempotently. Conflicting disclosures fail rather than being silently replaced.
This is not an exhaustive Apple privacy-schema or API-reason eligibility audit.

## Signed local archive (only after separate authorization)

```sh
bash tools/archive_ios_local.sh --sign /absolute/fresh/export /absolute/new/release-output
```

The export must have a valid current-source stamp, and the release output must
not exist or be inside the export. The script checks disk space and toolchain,
uses manual distribution signing with the existing team/profile/certificate,
and archives for generic iOS devices with deployment target 18.0. It does not
enable automatic provisioning or contact App Store Connect to update profiles.
Xcode resolves the profile locally; the resulting embedded profile is then
checked for exact name/team/app identity, expiry, non-debug Apple sign-in
entitlements, absence of device/ad-hoc/enterprise provisioning, and membership
of the actual code-signing leaf certificate in its DeveloperCertificates.
Failure must not be bypassed by switching to development signing.

Checks include signature validity, distribution authority, bundle/team identity,
Sign in with Apple entitlement, non-debug entitlement, matching frozen version
and build, plist/Mach-O minimum OS and SDK, and unchanged source/export evidence.
The archived privacy manifest must match the attested export and retain valid
collected-data field types. Missing get-task-allow is not treated as false.
`release-evidence.json` is written only after success, including source identity,
export stamp hash, toolchain, archive file hashes, ExportOptions hash and optional
IPA hashes. Preserve it together with logs and the archive. DerivedData remains
in the output for inspection; remove it manually only after reviewing evidence.

Append `--export-ipa` to export an IPA locally. The dedicated ExportOptions uses
`app-store-connect`, `destination=export`, manual signing, frozen version/build,
and disabled symbol upload. No upload or submission is performed. A successful
archive/IPA does not establish processing, TestFlight, submission or approval.

## Cloud boundary

`tools/export_ios.sh` no longer reads, preserves or copies a Cloud manifest or
marker files. Both local scripts reject Xcode Cloud environment markers.
`ci_scripts/export_current_ios.sh` and existing Cloud hooks remain untouched,
outside this change's scope; that old wrapper still contains Cloud-preservation
logic and is not a supported entry point for this local release. This is not
a claim that remote Cloud workflows have been removed or disabled.

## Lightweight regression checks

```sh
bash -n tools/export_ios.sh tools/archive_ios_local.sh
python3 -B -m unittest discover -s tests -p 'test_ios_local_pipeline.py'
python3 -B -m unittest discover -s tests -p 'test_ios_export_evidence.py'
node --test tools/check-ios-export-log.test.mjs tools/check-ios-simulator-arch.test.mjs
plutil -lint tools/ExportOptions.app-store-connect.plist
```

Pipeline tests compile every embedded Python block, check shell syntax, and use
isolated text/XML/plist/icon/profile fixtures and mocked disk measurements;
they never invoke build/signing tools. They do not
prove that a real signed archive can be produced on this machine. Do not run
the heavyweight commands above to validate an edit when disk space is limited.
