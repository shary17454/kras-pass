# Local macOS signing preflight

Read-only commands were run from the local macOS session with system access:

```
security list-keychains -d user
security find-identity -v -p codesigning
```

The user search list includes
`/Users/shrybnhshymbnmrzwqbnhwyd/Library/Keychains/login.keychain-db`.
The exact required identity is present and valid:
`Apple Distribution: Shary ALADHYANI (4HM66AD594)`.
Two valid identities were reported; no other identity was modified.

No P12 import, password request, certificate creation or revocation occurred.
This confirms identity availability only. Bundle ID, provisioning profile,
team/entitlement compatibility, final source/version/build, Archive creation,
codesign verification, upload, processing and review submission remain separate
gates. This is not a signed-build or upload result.

Using Xcode27's DEVELOPER_DIR without changing xcode-select, a fresh devicectl
inventory still reports the physical iPhone 16 Pro Max as unavailable. Connected
simulators are not physical-device battery/thermal or touch-session evidence.
No app was installed and no device pairing/profile setting was changed.
