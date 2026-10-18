# Original KRAS PASS music

These six AudioStreamWAV resources are generated entirely from this project's
`AudioManager._render_track` and `Synth`. They contain no third-party recordings,
music or game assets. The procedural composer remains the editable source.

Regenerate from the repository root:

```sh
godot --headless --path . tools/bake_original_music.tscn -- --test-data-dir=/tmp/kras-music-bake-save
```

Commit the regenerated `.res` files whenever composition parameters change.
The systems suite compares every PCM byte, sample format/rate, channels and loop
boundaries against the procedural source, and verifies bundled/cache playback.
Binary Godot resources preserve looping without WAV import settings. The bake
tool is excluded from app exports; the music resources are not excluded.
