# Loopback Endpoint Authority

Baseline: `f29824f82d6f34d6d5e4b090befa17e792be6f94`.
Runtime fix: `0e1def5ce74f0ab46f861ff6a963430576bb71f4`.

`RoomClient.connect_room` previously allowed plaintext transport by checking
whether the URL started with `ws://127.0.0.1:` or `ws://localhost:`. These strings
can identify user information rather than the destination host. For example,
the standard Node URL parser identifies `example.invalid` as the hostname of
`ws://localhost:8080@example.invalid/multiplayer`, while the old gate accepts it.
No claim is made that every such URL is accepted by every Godot URL parser or
that production credentials were exposed; the application gate was insufficient.

The policy now checks the complete authority before constructing a WebSocketPeer.
Plaintext permits only canonical `127.0.0.1` or `localhost`, an explicit decimal
port from 1 through 65535, and no user information or additional authority
components. `wss://` remains eligible; WebSocketPeer still performs full URL,
handshake and TLS validation. This is a transport policy, not a replacement URI
parser, DNS integrity guarantee or proof of certificate validation at runtime.
IPv6 loopback and uppercase host spellings were not previously permitted and
remain outside the plaintext exception. No production endpoint or secret changed.

Tests retain the original gate in the initial diagnostic process, then run the
same test suite against the correction:

- `/tmp/kras-loopback-policy-red.stdout`: 163 passed, 25 failed. The failures
  include accepting disallowed authorities and constructing sockets instead of
  returning `ERR_INVALID_PARAMETER` before connection. Test payloads contain no
  credentials; `.invalid` destination names were used.
- `/tmp/kras-loopback-policy-green.stdout`: all 188 assertions passed, log guard
  passed. Valid encrypted/canonical-loopback policy cases and invalid authority,
  user information, malformed ports and unsupported schemes are covered.
- `/tmp/kras-loopback-authority-compile.stdout`: all 331 scripts compile;
  log guard passed.
- `/tmp/kras-loopback-authority-live-network.log`: actual Godot host/client
  processes plus bots, seed 300041, completed `ring_rumble`, restored both peer
  identities, agreed on `[16,16,16,16]`, and observed 649 client snapshots.
  Both process logs passed the runtime guard. This tied sample verifies transport,
  state/result agreement and reconnect, not a decisive win or content balance.

Server event-loop maximum was 7344 ms; acceptable latency is not established.
Encrypted remote handshake, Internet four-player play, full CI, physical-device
performance and all other product/release acceptance gates remain open.
No main merge, distribution archive, upload or Apple review submission occurred.
