import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';

export const ARENA = 'src/arenas/arena.gd';
export const CAMERA = 'src/camera/arena_camera.gd';
export const FADER = 'src/camera/arena_occlusion_fader.gd';
export const RUNNER = 'tests/test_runner.gd';
export const INPUT_FILES = [ARENA, CAMERA, FADER, RUNNER];
const PIT_FUNCTIONS = ['_build_pit', '_add_static_box', '_add_static_cylinder'];
const CAMERA_FUNCTIONS = ['_process', '_update_camera', '_apply', '_live_targets',
  '_update_focus_and_zoom', '_wanted_focus', '_fit_arena_region', '_frame_shared_world', '_world_obstruction'];
const sha256 = source => createHash('sha256').update(source).digest('hex');

// Limited to these ordinary top-level GDScript functions; exclude following
// declarations and their comments so unrelated additions remain independent.
export function extractFunction(source, name) {
  assert.match(name, /^[A-Za-z_][A-Za-z0-9_]*$/);
  const lines = source.replaceAll('\r\n', '\n').split('\n');
  const start = lines.findIndex(line => line.startsWith(`func ${name}(`));
  assert.ok(start >= 0, `missing function ${name}`);
  let end = start + 1;
  while (end < lines.length && (!lines[end].trim() || /^[\t ]/.test(lines[end]))) end++;
  return lines.slice(start, end).join('\n').trimEnd() + '\n';
}

function approvedFunction(source, baseline, file, name, stripTags = false) {
  let actual = extractFunction(source, name);
  if (stripTags) {
    for (const target of ['body', 'top']) {
      const call = `_tag_camera_occluder(${target})`;
      const lines = actual.split('\n');
      assert.equal(lines.filter(line => line.trim() === call).length, 1, `one approved ${target} tag`);
      actual = lines.filter(line => line.trim() !== call).join('\n');
    }
  }
  const expected = baseline.files?.[file]?.[name];
  assert.match(expected ?? '', /^[a-f0-9]{64}$/, `declared approved hash for ${file}:${name}`);
  assert.equal(sha256(actual), expected, `approved function changed: ${file}:${name}`);
}

function noGameplayWrites(source) {
  assert.doesNotMatch(source, /\.(?:collision_layer|collision_mask|global_position|position|transform|scale|rotation|shape|visible|layers)\s*(?:[+*/-]?=)/,
    'visual code must not write geometry, visibility or collision state');
  assert.doesNotMatch(source, /\b(?:randf|randi|randomize|seed|take_hit|can_observe)\s*\(/,
    'visual code must not drive randomness, combat or AI');
}

export function checkRegistration(source) {
  const entry = /^\s*"res:\/\/tests\/suites\/test_duel_visibility\.gd",\s*$/gm;
  assert.equal([...source.matchAll(entry)].length, 1, 'duel visibility suite is registered exactly once');
}

export function checkPit(source, baseline) {
  for (const name of PIT_FUNCTIONS) approvedFunction(source, baseline, ARENA, name, name === '_build_pit');
  const tag = extractFunction(source, '_tag_camera_occluder');
  noGameplayWrites(tag);
  assert.match(tag, /body\.set_meta\(&"camera_occlusion_mesh", body\.get_path_to\(mesh\)\)/);
}

export function checkCamera(source, baseline) {
  for (const name of CAMERA_FUNCTIONS) approvedFunction(source, baseline, CAMERA, name);
  assert.doesNotMatch(extractFunction(source, '_process'), /_occlusion_fader\.update/);
  const physics = extractFunction(source, '_physics_process');
  assert.equal(physics.split('_occlusion_fader.update(self, arena, targets, delta)').length, 2,
    'one production update in the physics callback');
  noGameplayWrites(physics);
}

export function checkFader(source) {
  for (const [name, value] of Object.entries({INTERVAL: '0.1', MAX_TARGETS: '4', MAX_HITS_PER_RAY: '6', MAX_CACHE: '64'})) {
    const declaration = source.match(new RegExp(`^const ${name} := ([0-9.]+)$`, 'm'));
    assert.equal(declaration?.[1], value, `${name} retains its reviewed bound`);
  }
  const update = extractFunction(source, 'update');
  assert.match(update, /if not Engine\.is_in_physics_frame\(\):[\s\S]*?\n\t\treturn/,
    'idle calls must return before querying');
  assert.match(update, /mini\(targets\.size\(\), MAX_TARGETS\)/);
  assert.match(source, /PhysicsRayQueryParameters3D\.create\(origin, point, 1\)/);
  assert.match(source, /for attempt in MAX_HITS_PER_RAY:/);
  assert.match(source, /_elapsed < INTERVAL/);
  assert.match(source, /_cache\.size\(\) >= MAX_CACHE/);
  assert.match(source, /faded\.transparency = BaseMaterial3D\.TRANSPARENCY_ALPHA/);
  assert.match(source, /source\.duplicate\(\)/);
  assert.match(source, /clampf\(alpha, 0\.08, 0\.35\)/);
  assert.match(source, /mesh\.material_override = entry\.original/);
  assert.match(source, /_cache\.clear\(\)/);
  assert.doesNotMatch(source, /(?:mesh|geometry)\.transparency\s*=/);
  noGameplayWrites(source);
}

export function checkContract(sources, baseline) {
  assert.equal(baseline.schema, 1);
  checkRegistration(sources[RUNNER]);
  checkPit(sources[ARENA], baseline);
  checkCamera(sources[CAMERA], baseline);
  checkFader(sources[FADER]);
}
