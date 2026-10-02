// Server-owned tournament accounting. The host supplies match scores only.
import {higherIsBetter, validResultScore} from './game-scoring.js';

export class Tournament {
  constructor(count, settings, seed) {
    this.mode = settings.mode;
    this.target = settings.target;
    this.rotation = settings.rotation;
    this.entries = settings.entries.map(e => ({...e}));
    this.table = [...settings.points];
    this.seed = seed >>> 0;
    this.points = Array(count).fill(0);
    this.cups = Array(count).fill(0);
    this.lastAwards = Array(count).fill(0);
    this.round = 0;
    this.tieAttempts = 0;
    this.contenders = [];
    this.champions = [];
    this.complete = false;
    this.bag = [];
    this.lastEpoch = -1;
    this.current = null;
    this.tiebreakEntry = null;
  }

  next() {
    if (this.complete) throw new Error('tournament_complete');
    if (this.contenders.length && this.tiebreakEntry) {
      this.current = this.tiebreakEntry;
      return {...this.current};
    }
    if (this.rotation === 'manual') {
      this.current = this.entries[this.round % this.entries.length];
    } else {
      if (!this.bag.length) {
        this.bag = [...this.entries];
        for (let i = this.bag.length - 1; i > 0; i--) {
          this.seed = (Math.imul(this.seed, 1664525) + 1013904223) >>> 0;
          const j = this.seed % (i + 1);
          [this.bag[i], this.bag[j]] = [this.bag[j], this.bag[i]];
        }
      }
      this.current = this.bag.pop();
    }
    return {...this.current};
  }

  record(epoch, scores) {
    if (!this.current || this.complete || epoch <= this.lastEpoch) throw new Error('invalid_tournament_result');
    if (!Array.isArray(scores) || scores.length !== this.points.length
      || scores.some(s => !validResultScore(this.current.game, s))) throw new Error('invalid_tournament_result');
    const higher = higherIsBetter(this.current.game);
    const bestOf = values => higher ? Math.max(...values) : Math.min(...values);
    this.lastEpoch = epoch;
    this.lastAwards.fill(0);
    if (this.contenders.length) {
      this.tieAttempts++;
      const best = bestOf(this.contenders.map(i => scores[i]));
      this.contenders = this.contenders.filter(i => scores[i] === best);
      if (this.contenders.length === 1 || this.tieAttempts >= 3) this.finish(this.contenders);
      return;
    }
    const best = bestOf(scores);
    scores.forEach((score, slot) => {
      const before = scores.filter(s => higher ? s > score : s < score).length;
      const tied = scores.filter(s => s === score).length;
      const award = Math.ceil(this.table.slice(before, before + tied).reduce((a, b) => a + b, 0) / tied);
      this.points[slot] += award;
      if (score === best) this.cups[slot]++;
      this.lastAwards[slot] = this.mode === 'cups' ? Number(score === best) : award;
    });
    this.round++;
    const reached = this.mode === 'points' ? this.round >= this.target
      : Math.max(...this.cups) >= this.target || this.round >= this.target * this.points.length;
    if (reached) {
      const values = this.mode === 'cups' ? this.cups : this.points;
      const leaders = values.flatMap((v, i) => v === Math.max(...values) ? [i] : []);
      if (leaders.length === 1) this.finish(leaders);
      else {
        this.contenders = leaders;
        // Partners need an individual final because friendly fire is disabled.
        if (this.current.game === 'duo_clash') this.tiebreakEntry = {game: 'duel_pit', arena: 'duel_pit'};
      }
    }
  }

  finish(slots) { this.champions = [...slots]; this.complete = true; }

  view() {
    return {mode: this.mode, target: this.target, round: this.round, points: [...this.points],
      cups: [...this.cups], awards: [...this.lastAwards], contenders: [...this.contenders],
      tie_attempts: this.tieAttempts, champions: [...this.champions], complete: this.complete};
  }
}
