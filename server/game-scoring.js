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

// Kart controllers encode unfinished progress below a one-billion sentinel.
// A normal match sums up to ten rounds; tournaments submit one round at a time.
export function validResultScore(game, score, rounds = 1) {
  const higher = higherIsBetter(game);
  if (!Number.isInteger(rounds) || rounds < 1 || rounds > 10 || !Number.isInteger(score)) return false;
  const maximum = ['kart_sprint', 'sabaq_sawarikh'].includes(game) ? 1000000000 * rounds : 1000000;
  return score >= (higher ? -1000000 : 0) && score <= maximum;
}
