# Pinned Simulator Source Investigation

The official Godot `4.7.1-stable` tag was queried read-only via GitHub and
cloned into `/tmp/kras-godot-471-simulator-source`, outside the application
checkout. The clone completed successfully, has a clean worktree and HEAD
`a13da4feb8d8aefc283c3763d33a2f170a18d541`, matching the official engine's
reported revision. An early read before checkout completed had no HEAD/file;
the later completed checkout was verified rather than restarting the clone.

Primary source:
[Godot iOS build configuration](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/platform/ios/detect.py).

The configuration accepts `arch=arm64` and `simulator=yes`. However, it
explicitly sets Metal and Vulkan to false for simulator builds. This is a
limitation of this Godot build configuration, not a general claim that Apple's
Simulator cannot support Metal.

KRAS PASS currently uses `forward_plus` on desktop and `mobile` on mobile
(`project.godot` renderer settings). Therefore replacing the missing arm64
simulator library with a build from this source would not, by itself, establish
native renderer equivalence to the device release. A compatibility-renderer
preview cannot substitute for device graphics, FPS, battery or thermal QA.

No engine compilation was performed, no SCons installed, no installed engine
or template replaced, and no candidate exports/archives modified. No renderer
setting was changed to make a narrower test pass. The clean pinned source is
available for further compatible native UI investigation; physical-device
renderer/performance qualification remains required.
