import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { balanceSourceFingerprint } from '../tools/balance-source.mjs';

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kras-source-pin-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const name of ['src', 'scenes', 'data', 'tools']) fs.mkdirSync(path.join(root, name));
  fs.writeFileSync(path.join(root, 'project.godot'), 'project');
  return root;
}
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

test('source fingerprint matches the engine path/hash/newline contract', t => {
  const root = fixture(t);
  fs.writeFileSync(path.join(root, 'src', 'actor.gd'), 'actor');
  fs.writeFileSync(path.join(root, 'data', 'game.json'), '{"game":1}');
  const lines = [
    `res://data/game.json:${sha256('{"game":1}')}`,
    `res://project.godot:${sha256('project')}`,
    `res://src/actor.gd:${sha256('actor')}`,
  ];
  assert.equal(balanceSourceFingerprint(root), sha256(lines.join('\n')));
});

test('nested gameplay edits change the pin but ignored files do not', t => {
  const root = fixture(t);
  const before = balanceSourceFingerprint(root);
  fs.mkdirSync(path.join(root, 'src', '.cache'));
  fs.writeFileSync(path.join(root, 'src', '.cache', 'old.gd'), 'ignored');
  fs.writeFileSync(path.join(root, 'tools', 'test.mjs'), 'ignored');
  assert.equal(balanceSourceFingerprint(root), before);
  fs.mkdirSync(path.join(root, 'src', 'actors'));
  const actor = path.join(root, 'src', 'actors', 'actor.gd');
  fs.writeFileSync(actor, 'one');
  const first = balanceSourceFingerprint(root);
  assert.notEqual(first, before);
  fs.writeFileSync(actor, 'two');
  assert.notEqual(balanceSourceFingerprint(root), first);
});

test('each engine-qualified extension and project settings affects the pin', t => {
  const root = fixture(t);
  for (const extension of ['gd', 'tscn', 'scn', 'tres', 'res', 'json', 'gdshader']) {
    const before = balanceSourceFingerprint(root);
    fs.writeFileSync(path.join(root, 'tools', `file.${extension}`), extension);
    assert.notEqual(balanceSourceFingerprint(root), before);
  }
  const before = balanceSourceFingerprint(root);
  fs.writeFileSync(path.join(root, 'project.godot'), 'changed');
  assert.notEqual(balanceSourceFingerprint(root), before);
});

test('missing required roots and symlinks fail closed', t => {
  const root = fixture(t);
  fs.symlinkSync(path.join(root, 'project.godot'), path.join(root, 'src', 'linked.gd'));
  assert.throws(() => balanceSourceFingerprint(root), /symlink/);
  fs.unlinkSync(path.join(root, 'src', 'linked.gd'));
  fs.rmdirSync(path.join(root, 'data'));
  assert.throws(() => balanceSourceFingerprint(root), /ENOENT/);
  fs.symlinkSync(path.join(root, 'src'), path.join(root, 'data'));
  assert.throws(() => balanceSourceFingerprint(root), /Invalid source directory/);
});

test('campaign summary pins evidence to its actual checked-out source', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/balance-campaign.yml', import.meta.url), 'utf8');
  const summary = workflow.slice(workflow.indexOf('  summary:'), workflow.indexOf('  catalogue:'));
  assert.match(summary, /^\s+source_fingerprint="\$\(node tools\/balance-source\.mjs \.\)"$/m);
  assert.match(summary, /--source-fingerprint="\$source_fingerprint"/);
});
