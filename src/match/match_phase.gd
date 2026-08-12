class_name MatchPhase
extends RefCounted
## The match lifecycle, shared by the runtime, the HUD and the tests.
##
## Transitions are strictly forward except NEXT_ROUND -> INSTRUCTIONS, and every
## transition is funnelled through `MatchScene._set_phase()`. Keeping the legal
## edges in one table is what rules out the classic party-game bug where a
## round-end and a sudden-death trigger fire on the same frame and the match
## ends twice.

enum P {
	LOADING,
	INTRO,
	INSTRUCTIONS,
	COUNTDOWN,
	PLAYING,
	SUDDEN_DEATH,
	FINISH,
	RESULTS,
	REWARDS,
	NEXT_ROUND,
	DONE,
	PAUSED,
}

const NAMES := {
	P.LOADING: "loading", P.INTRO: "intro", P.INSTRUCTIONS: "instructions",
	P.COUNTDOWN: "countdown", P.PLAYING: "playing", P.SUDDEN_DEATH: "sudden_death",
	P.FINISH: "finish", P.RESULTS: "results", P.REWARDS: "rewards",
	P.NEXT_ROUND: "next_round", P.DONE: "done", P.PAUSED: "paused",
}

const LEGAL := {
	P.LOADING: [P.INTRO, P.DONE],
	P.INTRO: [P.INSTRUCTIONS, P.DONE],
	P.INSTRUCTIONS: [P.COUNTDOWN, P.DONE],
	P.COUNTDOWN: [P.PLAYING, P.DONE],
	P.PLAYING: [P.SUDDEN_DEATH, P.FINISH, P.PAUSED, P.DONE],
	P.SUDDEN_DEATH: [P.FINISH, P.PAUSED, P.DONE],
	P.FINISH: [P.RESULTS, P.DONE],
	P.RESULTS: [P.REWARDS, P.NEXT_ROUND, P.DONE],
	P.REWARDS: [P.NEXT_ROUND, P.DONE],
	P.NEXT_ROUND: [P.INSTRUCTIONS, P.DONE],
	P.PAUSED: [P.PLAYING, P.SUDDEN_DEATH, P.DONE],
	P.DONE: [],
}


static func name_of(p: int) -> String:
	return NAMES.get(p, "?")


static func can_go(from: int, to: int) -> bool:
	return LEGAL.get(from, []).has(to)


## Phases during which fighters simulate and the clock runs.
static func is_live(p: int) -> bool:
	return p == P.PLAYING or p == P.SUDDEN_DEATH
