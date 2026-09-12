import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, resolve, basename } from 'node:path';

const root = resolve(import.meta.dirname, '../assets/natural');
const assets = [
  ['rock_moss_set_01', '2k', 'model'],
  ['pine_sapling_small', '1k', 'model'],
  ['fern_02', '1k', 'model'],
  ['forrest_ground_01', '2k', 'texture'],
  ['aerial_rocks_01', '2k', 'texture'],
  ['gravel_floor', '2k', 'texture'],
];
const manifest = [];
async function download(path, file) {
  if (file.size > 35000000) throw new Error('Asset exceeds the mobile source budget: ' + path);
  const destination = resolve(root, path);
  const matches = data => createHash('md5').update(data).digest('hex') === file.md5;
  try { if (matches(await readFile(destination))) return; } catch {}
  const response = await fetch(file.url);
  if (!response.ok) throw new Error(`${response.status}: ${file.url}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (!matches(bytes)) throw new Error('Checksum failed: ' + path);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, bytes);
  console.log(path, bytes.length);
}
for (const [id, resolution, type] of assets) {
  const response = await fetch('https://api.polyhaven.com/files/' + id);
  if (!response.ok) throw new Error('Metadata request failed: ' + id);
  const data = await response.json();
  const files = {};
  if (type === 'model') {
    const model = data.gltf[resolution].gltf;
    files[basename(new URL(model.url).pathname)] = model;
    Object.assign(files, model.include);
  } else {
    for (const map of ['Diffuse', 'nor_gl', 'Rough']) {
      const file = data[map][resolution].jpg;
      files[basename(new URL(file.url).pathname)] = file;
    }
  }
  for (const [path, file] of Object.entries(files)) await download(id + '/' + path, file);
  manifest.push({ id, resolution, license: 'CC0-1.0', source: 'https://polyhaven.com/a/' + id,
    files: Object.fromEntries(Object.entries(files).map(([path, file]) => [path, { url: file.url, md5: file.md5 }])) });
}
await writeFile(resolve(root, 'sources.json'), JSON.stringify(manifest, null, 2) + '\n');
