import {readFileSync} from 'node:fs';

// Use the same checked-in catalogue as Godot, never a client's ranking flag.
const catalogue = JSON.parse(readFileSync(new URL('../data/minigames.json', import.meta.url), 'utf8'));
const directions = new Map();
for (const game of catalogue.games) {
  if (typeof game.id !== 'string' || !game.id || directions.has(game.id)
    || !['points', 'survival', 'race_time', 'lives'].includes(game.scoring ?? 'points')) {
    throw new Error('invalid_game_scoring_catalogue');
  }
  directions.set(game.id, game.scoring !== 'race_time');
}

export function higherIsBetter(game) {
  if (!directions.has(game)) throw new Error('unknown_game_scoring');
  return directions.get(game);
}
