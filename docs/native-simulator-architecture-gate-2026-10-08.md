# Simulator architecture gate

The local Xcode 27 Release simulator compilation of source
9f9c27072fb20a5456db5915fab81fad6d627a1f succeeded with explicit x86_64.
App: /tmp/kras-sim-9f9c270-derived/Build/Products/Release-iphonesimulator/KrasPass.app.
Build log: /tmp/kras-sim-9f9c270-build.log.
Its PCK SHA256 matches the separate device export:
a7bbf086b3e415bba9bd97a17c2ebedbd113dd0e99b29e9373edc02eec09a61a.

An isolated iOS 18.6 x86_64 device was created:
KRAS-QA-9f9c270-iPhone16Pro, 681EF34C-2737-4C9D-A4AB-013145FA6E03.
The inventory reported Booted, but boot-status observation and installation
did not produce a usable launch. The installation operation was stopped
(exit 130); no successful app launch or gameplay is claimed. The isolated
simulator was shut down successfully. No physical device installation occurred.

The export helper now defaults to the host architecture and checks the actual
engine archive with lipo before invoking the simulator compilation. Explicit
KRAS_IOS_SIM_ARCH=x86_64 remains available for a compatible legacy runtime.
It is never automatic fallback and does not qualify iOS 27. Metadata claiming
both architectures cannot override the actual binary check.

Seven Node tests pass, bash syntax validation and git diff --check pass.
Against the actual exported engine, arm64 check exits 1 with a missing-slice
diagnostic and x86_64 check exits 0. The architecture gate is not a rendering,
runtime, device performance or App Store signing test. A compatible engine
template and actual native launch remain required. This tool change is later
than the compiled source above; it does not restamp that export as current.

Chrome was freshly observed signed in and showing Kras Pass app 6801506973,
1.1.10 Ready for Distribution. No private review contact page was opened,
no build was uploaded, and no review submission was sent.
