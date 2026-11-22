import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';
import {ARENA, CAMERA, FADER, RUNNER, INPUT_FILES, extractFunction,
  checkRegistration, checkPit, checkCamera, checkFader, checkContract} from './contracts/duel_visibility_contract.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const baseline = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/duel_visibility_baseline.json'), 'utf8'));
const sources = Object.fromEntries(INPUT_FILES.map(file => [file, fs.readFileSync(path.join(root, file), 'utf8')]));

test('visibility suite remains registered without restricting other tests', () => {
  checkRegistration(sources[RUNNER]);
  checkRegistration(sources[RUNNER] + '\n# An unrelated runner feature can evolve independently.\n');
});

test('pit geometry and collider construction match approved original function hashes', () => {
  checkPit(sources[ARENA], baseline);
});

test('reviewed camera framing is preserved and fade queries stay in physics', () => {
  checkCamera(sources[CAMERA], baseline);
});

test('fade bounds, isolated materials, restoration and physics guard are preserved', () => {
  checkFader(sources[FADER]);
});

test('negative geometry, collider, render-query and budget mutations fail the actual contract', () => {
  const changes = [
    [ARENA, source => source.replace('def.param("step_height", 2.3)', 'def.param("step_height", 2.4)')],
    [ARENA, source => {
      const fn = extractFunction(source, '_add_static_box');
      return source.replace(fn, fn.replace('body.collision_layer = 1', 'body.collision_layer = 2'));
    }],
    [CAMERA, source => source.replace('func _process(delta: float) -> void:',
      'func _process(delta: float) -> void:\n\t_occlusion_fader.update(self, arena, targets, delta)')],
    [FADER, source => source.replace('if not Engine.is_in_physics_frame():', 'if false:')],
    [FADER, source => source.replace('const MAX_HITS_PER_RAY := 6', 'const MAX_HITS_PER_RAY := 60')],
    [FADER, source => source + '\nfunc unsafe_visual_write(body):\n\tbody.position += Vector3.UP\n'],
  ];
  for (const [file, mutate] of changes) {
    const altered = mutate(sources[file]);
    assert.notEqual(altered, sources[file], 'negative fixture actually changes ' + file);
    assert.throws(() => checkContract({...sources, [file]: altered}, baseline), assert.AssertionError);
  }
});

test('unrelated features and platform line endings do not require a historical checkout', () => {
  const unrelated = {...sources,
    [ARENA]: sources[ARENA] + '\nfunc unrelated_new_feature() -> int:\n\treturn 42\n',
    [CAMERA]: sources[CAMERA] + '\nfunc unrelated_camera_metadata() -> String:\n\treturn "future"\n',
    'src/future_feature.gd': 'extends Node\n',
  };
  checkContract(unrelated, baseline);
  checkContract(Object.fromEntries(Object.entries(sources).map(([file, source]) => [file, source.replaceAll('\n', '\r\n')])), baseline);
});
