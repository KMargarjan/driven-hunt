# Archived: the Forest Test's "turn" wave phase (task 122 round 2, 2026-10-06)

Removed from `src/server/ForestTest/init.luau` because it was unreachable: `ForestTest.wavePhase`'s
`turnsBack` branch answers only `"done"` or `"push"`, so `beaterPosition`'s `if phase == "turn"`
could never run and four numbers fed nothing. Found by the Reviewer, task 122 round 1.

Removed, verbatim:

```lua
-- in ForestTest.WAVE
	turnAtSeconds = 9, -- a `turnsBack` wave is pushed for this long before it is turned
	turnSeconds = 8,
	aheadStuds = 26, -- in front of the FOREMOST, to turn it
	turnGiveUpDz = 45, -- an AVOID takes a few seconds to swing; do not give up while it is working

-- in ForestTest.beaterPosition
	if phase == "turn" then
		return rear + Vector3.new(0, 0, -wave.aheadStuds)
	end
```

`export type Phase` lost its `"turn"` member in the same change.

## Why it exists at all, kept because the measurements cost a round

Karen asked for *"several animals cross road / several go back"*. Three ways of turning a wave with a
second beater were measured against the live world and **all three crossed anyway**:

* a beater 11 studs ahead -- inside `SENSE.FLUSH_STUDS` (15), so the flush row fires and FLEE heads
  for `exitZ`. More drive, not a turn.
* a beater 26 studs ahead (`aheadStuds`) -- outside the flush radius, but staged on the FOREMOST
  animal it chased the one that had bolted: gap 261 studs, visible to nobody.
* staged on the centroid -- the right place, but the herd closes on it, the gap falls under 15
  (measured 12.8) and the flush row fires anyway.

What turns an animal is AVOID, and AVOID is a reaction a CALM animal has; one already fleeing past a
threat cannot be swung by it. Making that work is a change to `Brain`'s precedence, which was out of
scope. What shipped instead is a push that STOPS at `turnAtDz`: they coast in, come off FLEE and
settle north of the road, which from a stand reads as a group that came down and thought better of
it. **That is not Karen's "go back" as an animation of refusal, and the gap is in the report.**

To bring it back: restore the block above and the `"turn"` member of `Phase`, and give the Brain a
precedence in which a NOTICED threat can turn a fleeing animal.
