const finite = value => Number.isFinite(value) && Math.abs(value) <= 10000;
const vector = value => Array.isArray(value) && value.length === 3 && value.every(finite);

export function validScrapWorld(data, count) {
  const serial = value => Number.isInteger(value) && value >= 0 && value <= 1000000;
  return Number.isInteger(count) && count >= 2 && count <= 4
    && data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 5 && Number.isFinite(data.maximum)
    && data.maximum >= 1 && data.maximum <= 1000 && serial(data.ram) && vector(data.position)
    && Array.isArray(data.health) && data.health.length === count
    && data.health.every(value => Number.isFinite(value) && value >= 0 && value <= data.maximum)
    && Array.isArray(data.wrecks) && data.wrecks.length === count
    && data.wrecks.every((value, slot) => serial(value) && value <= 1 && (value === 0 || data.health[slot] === 0));
}

export function validTurretWorld(data, count, horizontal = true) {
  if (!Number.isInteger(count) || count < 2 || count > 4 || !data || typeof data !== 'object' || Array.isArray(data)
    || Object.keys(data).length !== 3 || !Array.isArray(data.shots) || data.shots.length > 128) return false;
  for (const field of ['cooldowns', 'damage']) {
    if (!Array.isArray(data[field]) || data[field].length !== count
      || !data[field].every(value => Number.isFinite(value) && value >= 0 && value <= (field === 'cooldowns' ? 60 : 10000))) return false;
  }
  const ids = new Set();
  return data.shots.every(row => {
    if (!row || typeof row !== 'object' || Array.isArray(row) || Object.keys(row).length !== 5
      || typeof row.id !== 'string' || !/^[1-9][0-9]{0,17}$/.test(row.id) || ids.has(row.id)
      || !Number.isInteger(row.generation) || row.generation < 1 || row.generation > 1000000
      || !Number.isInteger(row.shooter) || row.shooter < 0 || row.shooter >= count
      || !vector(row.position) || !vector(row.direction)
      || (horizontal && Math.abs(row.direction[1]) > .001)
      || Math.abs(row.direction.reduce((sum, value) => sum + value * value, 0) - 1) > .01) return false;
    ids.add(row.id); return true;
  });
}

export function validTankWorld(data, count) {
  if (!data || typeof data !== 'object' || Array.isArray(data)
    || Object.keys(data).length !== 7 || !Array.isArray(data.shots) || data.shots.length > 128) return false;
  const baseShots = [];
  for (const row of data.shots) {
    if (!row || typeof row !== 'object' || Array.isArray(row) || Object.keys(row).length !== 7
      || !Number.isInteger(row.kind) || row.kind < 0 || row.kind > 6
      || !Number.isFinite(row.fuse) || row.fuse < -1 || row.fuse > 2
      || (row.fuse < 0 && row.fuse !== -1) || (row.kind !== 6 && row.fuse !== -1)) return false;
    const {kind, fuse, ...base} = row;
    baseShots.push(base);
  }
  if (!validTurretWorld({shots: baseShots, cooldowns: data.cooldowns, damage: data.damage}, count, false)) return false;
  for (const field of ['armor', 'ammo', 'shell_types']) {
    if (!Array.isArray(data[field]) || data[field].length !== count
      || !data[field].every(value => Number.isInteger(value) && value >= 0 && value <= (field === 'armor' ? 100 : 6))) return false;
  }
  for (let slot = 0; slot < count; slot++) {
    const ammo = data.ammo[slot], kind = data.shell_types[slot];
    if ((ammo === 0) !== (kind === 0) || ammo > (kind === 1 ? 6 : 3)) return false;
  }
  return Array.isArray(data.crates) && data.crates.length === 5 && data.crates.every(row =>
    row && typeof row === 'object' && !Array.isArray(row) && Object.keys(row).length === 2
    && Number.isFinite(row.cooldown) && row.cooldown >= 0 && row.cooldown <= 9
    && Number.isFinite(row.rotation) && Math.abs(row.rotation) <= Math.PI);
}

export function validHurdleWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4
    && data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 2 && Number.isFinite(data.elapsed)
    && data.elapsed >= 0 && data.elapsed <= 3600
    && Array.isArray(data.times) && data.times.length === count
    && data.times.every(time => Number.isInteger(time) && time >= 0 && time <= 360000
      && (time === 99999 || time <= Math.round(data.elapsed * 100)));
}

export function validCrateWorld(data, count, lab = false) {
  const integer = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;
  if (!integer(count, 2, 4) || !data || typeof data !== 'object' || Array.isArray(data)
    || Object.keys(data).length !== 5 || !integer(data.break_sequence, 0, 1000000)
    || !integer(data.break_kind, 0, lab ? 4 : 1) || !vector(data.break_position)
    || !Array.isArray(data.crates) || data.crates.length > 14
    || !Array.isArray(data.shots) || data.shots.length > (lab ? 128 : 0)) return false;
  const ids = new Set();
  const id = value => {
    if (typeof value !== 'string' || !/^[1-9][0-9]{0,17}$/.test(value) || ids.has(value)) return false;
    ids.add(value); return true;
  };
  if (!data.crates.every(row => row && typeof row === 'object' && !Array.isArray(row)
    && Object.keys(row).length === 3 && id(row.id) && vector(row.position) && integer(row.kind, 0, lab ? 2 : 1))) return false;
  return data.shots.every(row => row && typeof row === 'object' && !Array.isArray(row)
    && Object.keys(row).length === 4 && id(row.id) && vector(row.position) && vector(row.direction)
    && integer(row.shooter, 0, count - 1) && Math.abs(row.direction[1]) <= .001
    && Math.abs(row.direction.reduce((sum, value) => sum + value * value, 0) - 1) <= .01);
}

export function validBlastWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && ['position', 'velocity', 'explosion_position'].every(key => vector(data[key]))
    && ['generation', 'explosion_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000)
    && typeof data.detonated === 'boolean'
    && Number.isFinite(data.fuse_max) && data.fuse_max > 0 && data.fuse_max <= 60
    && Number.isFinite(data.fuse) && data.fuse >= 0 && data.fuse <= data.fuse_max
    && (!data.detonated || data.fuse === 0);
}

export function validCrumbleWorld(data, tileCount = 113) {
  return !!data && Array.isArray(data.tiles) && data.tiles.length === tileCount
    && data.tiles.every(row => Array.isArray(row) && row.length === 4 && row.every(Number.isFinite)
      && Number.isInteger(row[0]) && row[0] >= 0 && row[0] <= 3
      && row[1] >= 0 && row[1] <= 10 && row[2] >= -32 && row[2] <= 0
      && Number.isInteger(row[3]) && row[3] >= 0 && row[3] <= 1000000
      && (row[0] !== 0 || (row[1] === 0 && row[2] === 0))
      && (row[0] !== 1 || (row[1] <= .9 && row[2] === 0)));
}

export function validColorWorld(data) {
  return validCrumbleWorld(data, 121)
    && Array.isArray(data.colors) && data.colors.length === 121
    && data.colors.every(color => Number.isInteger(color) && color >= 0 && color <= 3)
    && Number.isInteger(data.called) && data.called >= 0 && data.called <= 3
    && Number.isInteger(data.stage) && data.stage >= 0 && data.stage <= 2
    && Number.isFinite(data.timer) && data.timer >= 0 && data.timer <= 60
    && ['call_sequence', 'drop_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000);
}

export function validSkyWorld(data, count) {
  return validGoalGuardWorld(data, count)
    && Object.entries({bank: 1, warning: 1.2, tilting: 4, cycle: 9}).every(([key, limit]) => Number.isFinite(data[key]) && data[key] >= 0 && data[key] <= limit)
    && Number.isInteger(data.engine) && data.engine >= -1 && data.engine <= 3
    && ['warning_sequence', 'tilt_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000)
    && (data.engine >= 0 || (data.bank === 0 && data.warning === 0 && data.tilting === 0));
}

export function validStormWorld(data, count) {
  return validGoalGuardWorld(data, count, 2)
    && Number.isFinite(data.rotor) && data.rotor >= 0 && data.rotor <= Math.PI * 2
    && Number.isFinite(data.windup) && data.windup >= 0 && data.windup <= 1.6
    && Number.isFinite(data.volley_timer) && data.volley_timer >= 0 && data.volley_timer <= 8
    && ['warning_sequence', 'volley_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000);
}

export function validMagnetWorld(data, count) {
  return validGoalGuardWorld(data, count)
    && Array.isArray(data.magnet_charge) && data.magnet_charge.length === count
    && data.magnet_charge.every(value => Number.isFinite(value) && value >= 0 && value <= 1)
    && Array.isArray(data.magnet_active) && data.magnet_active.length === count
    && data.magnet_active.every(value => Number.isFinite(value) && value >= 0 && value <= 1.1)
    && Array.isArray(data.held) && data.held.length === data.balls.length
    && data.held.every(owner => Number.isInteger(owner) && owner >= -1 && owner < count);
}

export function validSaboteurWorld(data, count) {
  return validPaintWorld(data, count) && vector(data.drone)
    && vector(data.scrub_position)
    && ['warning_sequence', 'scrub_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000)
    && Number.isFinite(data.rotor) && data.rotor >= 0 && data.rotor <= Math.PI * 2
    && Number.isInteger(data.target) && data.target >= -1 && data.target < 169
    && Number.isFinite(data.mark) && data.mark >= 0 && data.mark <= 1.5
    && Number.isFinite(data.cycle) && data.cycle >= 0 && data.cycle <= 3.4
    && (data.target >= 0 || data.mark === 0);
}

export function validEchoWorld(data, count) {
  const integer = (value, low, high) => Number.isInteger(value) && value >= low && value <= high;
  if (!integer(count, 2, 4) || !data || typeof data !== 'object' || Array.isArray(data)
    || Object.keys(data).length !== 13 || !integer(data.stage, 0, 2)
    || !integer(data.serial, 0, 1000000) || !integer(data.length, 1, 9)
    || !integer(data.pad, -1, 4) || !integer(data.step, -1, data.length - 1)
    || !Number.isFinite(data.flash_left) || data.flash_left < 0 || data.flash_left > 5
    || !['flash_sequence', 'correct_sequence', 'wrong_sequence', 'finish_sequence']
      .every(key => integer(data[key], 0, 1000000))) return false;
  if (data.pad < 0 ? (data.step !== -1 || data.flash_left !== 0)
    : (data.stage !== 0 || data.step < 0 || data.flash_left <= 0)) return false;
  for (const key of ['progress', 'mistakes']) {
    if (!Array.isArray(data[key]) || data[key].length !== count
      || !data[key].every(value => integer(value, 0, key === 'progress' ? data.length : 1000000))) return false;
  }
  if (!Array.isArray(data.finished) || data.finished.length > count) return false;
  const seen = new Set();
  for (const slot of data.finished) {
    if (!integer(slot, 0, count - 1) || seen.has(slot) || data.progress[slot] !== data.length) return false;
    seen.add(slot);
  }
  return data.progress.every((progress, slot) => (progress === data.length) === seen.has(slot)
    && (data.stage !== 0 || progress === 0));
}

export function validDrawWorld(data, count) {
  const integer = (value, max) => Number.isInteger(value) && value >= 0 && value <= max;
  if (!Number.isInteger(count) || count < 2 || count > 4 || !data || typeof data !== 'object'
    || Array.isArray(data) || Object.keys(data).length !== 8
    || !integer(data.stage, 2) || !integer(data.prompt, 1000000)
    || !['signal_sequence', 'correct_sequence', 'wrong_sequence', 'resolve_sequence']
      .every(key => integer(data[key], 1000000))
    || !Array.isArray(data.locked) || data.locked.length !== count
    || !data.locked.every(value => typeof value === 'boolean')
    || !Array.isArray(data.order) || data.order.length > count) return false;
  const seen = new Set();
  for (const slot of data.order) {
    if (!integer(slot, count - 1) || seen.has(slot) || data.locked[slot]) return false;
    seen.add(slot);
  }
  return data.stage !== 0 || data.order.length === 0;
}

export function validPaintWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Array.isArray(data.owners) && data.owners.length === 169
    && data.owners.every(owner => Number.isInteger(owner) && owner >= -1 && owner < count);
}

export function validTagWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Number.isInteger(data.hunter) && data.hunter >= -1 && data.hunter < count
    && Number.isFinite(data.grace) && data.grace >= 0 && data.grace <= 1.31;
}

export function validZoneWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && vector(data.position) && Number.isFinite(data.radius) && data.radius >= .1 && data.radius <= 10
    && typeof data.color === 'string' && /^[0-9a-fA-F]{8}$/.test(data.color);
}

export function validRelicWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Number.isInteger(data.holder) && data.holder >= -1 && data.holder < count
    && Array.isArray(data.items) && data.items.length <= 1
    && (data.holder < 0 || data.items.length === 0)
    && validCollectionWorld({items: data.items, carrying: Array(count).fill(0)}, count, 'gem');
}

export function validTideWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 2
    && Number.isFinite(data.level) && Math.abs(data.level) <= 1000
    && Number.isFinite(data.age) && data.age >= 0 && data.age <= 3600;
}

export function validSweeperWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 1 && Array.isArray(data.angles)
    && data.angles.length === 3
    && data.angles.every(angle => Number.isFinite(angle) && Math.abs(angle) <= Math.PI);
}

export function validDuelWorld(data, count) {
  return count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 2
    && Array.isArray(data.lives) && data.lives.length === count
    && data.lives.every(life => Number.isInteger(life) && life >= 0 && life <= 3)
    && Array.isArray(data.damage) && data.damage.length === count
    && data.damage.every(value => Number.isFinite(value) && value >= 0 && value <= 10000);
}

export function validBumperWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 2
    && Array.isArray(data.hits) && data.hits.length === 5
    && data.hits.every(value => Number.isInteger(value) && value >= 0 && value <= 1000000)
    && Array.isArray(data.scales) && data.scales.length === 5
    && data.scales.every(scale => Array.isArray(scale) && scale.length === 3
      && scale.every((value, axis) => Number.isFinite(value)
        && value >= (axis === 1 ? .8 : 1) - .00001
        && value <= (axis === 1 ? 1 : 1.25) + .00001));
}

export function validDuoWorld(data, count, arena = '') {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 5
    && validDuelWorld({lives: data.lives, damage: data.damage}, count)
    && data.lives.every(life => life <= 2)
    && Array.isArray(data.team_scores) && data.team_scores.length === 2
    && data.team_scores.every(score => Number.isInteger(score) && score >= 0 && score <= 100000)
    && ['sweeper_ring', 'bumper_bowl'].includes(data.arena)
    && (arena === '' || data.arena === arena)
    && (data.arena === 'sweeper_ring' ? validSweeperWorld(data.hazards) : validBumperWorld(data.hazards));
}

export function validFloeWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && Object.keys(data).length === 2
    && Number.isFinite(data.age) && data.age >= 0 && data.age <= 3600
    && Array.isArray(data.positions) && data.positions.length === 3
    && data.positions.every(position => Array.isArray(position) && position.length === 3
      && position.every(value => Number.isFinite(value) && Math.abs(value) <= 1000));
}

export function validGoalGuardWorld(data, count, extraBalls = 0) {
  return count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Array.isArray(data.charges) && data.charges.length === count
    && data.charges.every(value => Number.isFinite(value) && value >= 0 && value <= 1)
    && Array.isArray(data.balls) && data.balls.length >= 1 && data.balls.length <= count + extraBalls
    && data.balls.every(ball => ball != null && typeof ball === 'object'
      && typeof ball.heavy === 'boolean' && Number.isInteger(ball.generation)
      && ball.generation >= 0 && ball.generation <= 1000000
      && vector(ball.position) && vector(ball.velocity));
}

export function validCollectionWorld(data, count, kind) {
  const relay = kind === 'crate';
  if (count < 2 || count > 4 || !data || typeof data !== 'object' || Array.isArray(data)
    || !Array.isArray(data.carrying) || data.carrying.length !== count
    || !data.carrying.every(v => Number.isInteger(v) && v >= 0 && v <= (relay ? 1 : 8))
    || !Array.isArray(data.items) || data.items.length > (relay ? 8 : 256)
    || (relay && Object.keys(data).length !== 2)) return false;
  const ids = new Set();
  return data.items.every(row => {
    if (!row || typeof row !== 'object' || typeof row.id !== 'string'
      || !/^[1-9][0-9]{0,18}$/.test(row.id) || BigInt(row.id) > 9223372036854775807n || ids.has(row.id)) return false;
    ids.add(row.id);
    return row.kind === kind && vector(row.position)
      && Number.isFinite(row.rotation) && Math.abs(row.rotation) <= 3.142
      && typeof row.color === 'string' && /^[0-9a-fA-F]{8}$/.test(row.color)
      && Number.isFinite(row.size) && row.size >= .05 && row.size <= 3
      && Number.isInteger(row.value) && row.value >= 1 && row.value <= 1000000;
  });
}
