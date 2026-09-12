# Natural environment assets

Models and photographed PBR textures by Poly Haven and its contributing artists.
License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
License statement: https://polyhaven.com/license

See sources.json for original asset URLs, resolutions, file URLs and checksums.
Run node tools/fetch_natural_assets.mjs to restore verified source downloads.

These are bundled assets; the game does not contact Poly Haven at runtime.

pine_mobile.glb is a derived, simplified version of pine_sapling_small:
npx @gltf-transform/cli@4.5.0 simplify assets/natural/pine_sapling_small/pine_sapling_small_1k.gltf assets/natural/pine_mobile.glb --ratio 0.08 --error 0.04
The full-resolution source folder is excluded from Godot import/export.
