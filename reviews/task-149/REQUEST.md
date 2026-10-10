# Task 149 - the RIFLE flag goes on. The three boar defects are NOT in this request.

Task: 149
Round: 1
Base: main (`d83d3ed`, task 148 merged as PR #131)
Code commit: `5f604e0f17c3c1a237800b4ae41f8cad64432568`

```
[harness] PASS: 33/33 checks @ 5f604e0f17c3c1a237800b4ae41f8cad64432568 (clean tree) scope=all
```

`test2` is N/A: the diff is `Flags` and one client spec — nothing in `TWO_PLAYER_PATHS`.

Karen, 2026-10-10 ~18:10: *"weapons is ok for now / yes boars still sometimes stand after dead and
stays / also when I shoot sometimes they dont run we need to make when there is shoot they runn all
around some radius, now looks odd I shoot and few run and next to them another group walk / and also
when they cross another side they have to run away not stay and od circles"*. Transcribed in
`PLAYTEST.md`.

**THIS REQUEST IS ITEM 0 ONLY.** Items 1, 2 and 3 are not in it, and claim 6 says why. **No Architect
run:** a flag default and a spec bound.

## The claims

1. **THE RIFLE FLAG'S DEFAULT IS ON, on Karen's word.** *"weapons is ok for now"* is the OK the row
   has been waiting for since task 140, after eight rounds of her own notes on the sight picture, the
   hands, the bolt and the magazine. Three lines, as CLAUDE.md's feature-flag rule asks: the default,
   the comment saying when and on whose word, and the row's `why`. **Verify:** `Flags.DEFAULTS.RIFLE`.

2. **THE ROW STAYS, AND THAT IS THE ROLLBACK.** One line back to `false` is the game before task 140
   — one Tool in the hand — which is what the rule asks a flipped flag to keep.

3. **THE `why` STOPPED DESCRIBING A WEAPON THAT NO LONGER EXISTS.** It still named slot 3 and the
   open-sighted rifle that task 148 retired. That was a note queued as 148a; it is fixed here because
   this commit is the one that touches the row.

4. **THE FORREST TEST'S OVERRIDE IS CLEARED** — `python tools/flags.py clear` — because the default
   now does what the override did. `tools/flags.py` reads `RIFLE on / none / on`.

5. **THE FLIP BROKE A SPEC AND THE GATE CAUGHT IT.** `weapon_client.spec`'s "listens to ONE Tool"
   asserted `watchedTools() <= 1`, which was the whole loadout when it was written. The leak it
   guards is "one more set of connections per respawn", so the bound is `#Weapons.loadout()` now and
   the case reports what it saw: `weapon-client: 2 tool(s) watched, loadout is 2`. A third weapon
   would not turn it into a tautology either.

6. **ITEMS 1, 2 AND 3 ARE NOT DELIVERED, AND I AM STOPPING RATHER THAN GUESSING.** All three are
   defined by measurement — *"0 upright dead over 30+ kills"*, *"how many ran within 1 s — target
   100%"*, *"max dwell and circle windows, targets 0 and 0"* — and I could not land a single
   confirmed kill through the harness, so there is no before-table for any of them. What I have is in
   the next two sections: one root cause found by reading, and four facts about the harness that the
   next attempt should start from rather than rediscover.

## Item 2: the root cause IS found, by arithmetic, and it is written in the code's own comment

`Report.CONFIG.METRES_PER_STUD = 0.28`, so **1 m = 3.57 studs**.

```
SENSE.SHOT_AUDIBLE_STUDS = 120 studs = 33.6 m
Karen's hits, task 138:    30 to 71 m = 107 to 254 studs
her kill line, task 148:   "60 m"     = 214 studs
```

The comment above that constant reads *"120 is about twice the distance she shoots at (her hits in
task 138 were at 30 to 71 m) so the pack she fires into always runs"*. **It compares studs with
metres.** 120 studs is **0.47 to 1.12** of her shot distance — at the short end the radius barely
reaches the animal she hit, and at the long end it does not reach it at all. The factor the sentence
is out by is **3.57 studs per metre**.

**ROUND 1 OF THIS REQUEST SAID "a THIRD" AND "out by a factor of twelve", AND BOTH WERE WRONG** (the
Reviewer's note): twelve is 3.57 squared, and a third is not what 0.47-1.12 is. The direction stands
and so does everything the fix rests on; the numbers above are the corrected ones.

And the radius is measured from one point only: `ForestTestBoot` and `MatchBoot` both call
`runtime:hearShot(shot.muzzle)`, and `Brain._hearSound` refuses anything past
`SHOT_AUDIBLE_STUDS` **from the muzzle**. The shot payload carries no impact point at all.

That is exactly *"I shoot and few run and next to them another group walk"*: the few that run are the
ones near HER, and the group next to the animal she hit never heard it.

**The fix I did not ship** (no before/after measurement to prove it): give the shot payload its aim
point, have `hearShot` take the muzzle AND the impact, and set the radius from her real shooting
distance rather than from a mis-converted one.

## What the harness does and does not do, so the next attempt starts further on

* **A fixed screen point does not hit anything.** 62 shots over 150 s killed nothing.
* **The shotgun holds two and never reloads itself.** Those 62 shots were fired at a readout that
  had said `x[x]` since the third. Any shooting driver must use the rifle or press R.
* **A live boar leaves the aim ray in under a second.** Placing one on the camera's look vector and
  firing 0.8 s later missed every time; it has a mover and an AlignOrientation and it walks away.
  It needs anchoring for the shot and releasing straight after.
* **The viewport is 969 x 784, so the centre is (484, 392)**, not (960, 540).
* **AND THE RIFLE STRANDS ITS LAST MAGAZINE.** Measured, repeatedly: the readout walks
  `3/3 .416 9 → … → 3/3 .416 6 → … → 3/3 .416 3 → … → 0/3 .416 3` and **stops there** — magazine
  empty, three rounds still in the pocket, `AUTO_RELOAD_WHEN_EMPTY = true`, and no further fire. I
  could not tell whether R would clear it (`send_input` rejected my keyboard payload), so this is
  reported as an observation and not as a diagnosis. It is the first thing to check next, because it
  blocks every shooting measurement this task needs.

## Standing rule A, Forest Test, 85 s, with the flag's new DEFAULT (no override)

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 27 boars alive

Rule 5 screenshot: **N/A** — nothing drawn changed. The frames the dispatch asks for belong to items
1 and 2, which are not here.

## What I could not verify

* **Everything in items 1 and 3.** I never reproduced the standing carcass, so I have no evidence
  about which path leaves it upright — only a reading of `Body.collapse`, which skips the box roll
  whenever a visual exists and leaves the falling to the death clip. The Forest Test publishes all
  19 clips (`[BoarAssetsBoot] all 19 boar clips have an animation asset id`), so the obvious
  no-clip explanation is NOT this world's.
* **Item 3 was not started at all.**
