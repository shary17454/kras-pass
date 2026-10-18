# Original KRAS PASS Sound Effects And Ambience

The 38 sound effects here and two loops under ../ambience are generated solely
from this project's AudioManager._render_sfx/_render_ambience and Synth. No
third-party recordings or copyrighted game sounds are used by these resources.
The procedural source remains editable and runtime fallback remains available.

Regenerate from the repository root after changing sound composition:

```sh
godot --headless --path . tools/bake_original_sfx.tscn -- --test-data-dir=/tmp/kras-sfx-bake-save
```

Commit regenerated binary AudioStreamWAV .res resources. The systems suite
compares every PCM byte, format, rate, channels and loop boundaries to Synth,
and verifies resource caching and shoot/victory aliases. One-shot SFX remain
non-looping; engine and wind remain looping. Existing bus controls and voice
pool limits are unchanged.

The bake tool supports --benchmark-only to measure cold bank loading, but this
is a desktop operation benchmark, not gameplay FPS, phone battery or thermal
qualification. Tools/tests are excluded from app exports; audio assets are not.
