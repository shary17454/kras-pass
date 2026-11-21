# Local signing and frozen export policy

Fresh local macOS inspection, not an archive or upload result.
security find-identity -v -p codesigning reports the requested valid identity:
Apple Distribution: Shary ALADHYANI (4HM66AD594), public certificate fingerprint
C81811A21B592B030D57CD5B180227BDDADEA4C1.
No P12, password, import, new certificate, revocation or Keychain change.
Local Xcode 27.0, build 27A266a, was selected explicitly via DEVELOPER_DIR.

Matching existing App Store profile:
Kras Pass App Store Xcode 27 2026-09-20.
application-identifier: 4HM66AD594.com.shary.kraspass.
TeamIdentifier: 4HM66AD594. Expiration: 2027-09-19 17:59:00 UTC.
get-task-allow=false; no ProvisionedDevices; not ProvisionsAllDevices.
Apple Sign In entitlement: Default. Its DeveloperCertificates include the
requested Distribution fingerprint. Unrelated profile/device data was not
reported. This establishes profile compatibility, not a successful signing
operation or an embedded-profile check of a future archive.

The local Xcode 27 help explicitly says manageAppVersionAndBuildNumber defaults
to YES on upload. The repository export plist omitted that key and used the
generic Apple Distribution selector. The new policy sets:

- manageAppVersionAndBuildNumber=false, preserving the frozen archive build.
- signingStyle=manual, preventing automatic distribution profile/certificate creation.
- signingCertificate=the user's exact existing identity name.
- Existing Bundle ID, team and named App Store profile remain unchanged.

One new regression test failed before the policy edit (None is not False).
Afterward all 16 Python export-evidence/policy tests pass, plist validation
passes and git diff --check passes. Raw red/green logs are retained at
../qualification-signing-export-policy-2026-10-08/.

Current development configuration still reads 1.1.11 (110). No fresh final
upload number was chosen and no old archive is re-labelled with new source.
Before archive: complete product/device/production gates, refresh Apple build
inventory, commit the intended release numbers/source and verify the remote
commit. After archive: inspect actual app identity/version/build, signature,
team and embedded profile, then separately validate export/upload/processing
and selected App Review build. Profile/identity inspection alone proves none
of those later steps. No Xcode Cloud was used.

Ongoing core run 37836805471 is pinned to b6a452026b530ec7a4249d3261ab0d86412dbfba
and does not contain this later export-policy test. It was not cancelled or
restarted. All-game networking and natural balance campaigns continue on
their own previously recorded commits; their results must retain source IDs.
