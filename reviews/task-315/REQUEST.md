# Task 315 -- the shooting range moves straight out of the shop door

Task: 315
Round: 3
Base: d4b10eda (origin/main)
Code commit: e8895a55a8111827e0aa945597ee95647f016ac4

```
[harness] PASS: 34/34 checks @ e8895a55a8111827e0aa945597ee95647f016ac4 (clean tree) scope=auto:light,lobby,match,range
```

`test2` is **N/A** and that is the tool's answer, not an opinion: `agents.needs_two_player` over this
branch's changed files returns `[]`.

**Karen, 2026-10-30, with a frame:** *"those trees can be removed and shooting range can be moved
there that I can directly from shop walk to shooting range same distance but straight"*.

Design: `docs/design/shooting-range-lobby.md` (task 315, ARCH_RESULT PASS). Measurements before any
code: `reviews/task-315/BRIEF.md`. Round-3 authorisation: `ESCALATE.md`, Director 2026-10-30 23:50.

---

## This round is SPEC-ONLY, and that is why round 2's evidence still stands

Round 2 returned one blocking finding and I agreed with it. The Director authorised exactly its two
items, spec-only. **`src/` does not move**, so every live proof in Karen's place and every frame
described in round 2 still covers the shipped code -- the full round-2 record is
`reviews/task-315/RESULT.md` and the branch's round-2 request commit `03bc9012`.

## Claims

**1. Nothing but two spec files changed since the reviewed commit.**
*Verify:* `git diff --name-only c9086a27..e8895a55` -> `tests/server/lobby.spec.luau`,
`tests/server/lobby_live.spec.luau` and the paperwork of round 2; `git diff c9086a27..e8895a55 -- src`
is empty.

**2. The production wiring has a case now (round 2, finding 1, half one).**
`tests/server/lobby_live.spec.luau`, *"carries the corridor's two counters through Lobby.stats, and
reads 0 with no range"*: `keepClear` / `sightline` go in **through `Lobby.start`** in the
`fresh(bin, function(world) ... end)` shape that file already uses for `homeAreas`, with the wood
handed in through `world.templates` (no templates, no trees, and then a counter reads 0 for the wrong
reason) and the world's own trunk planted where the pine stood. It asserts
`Lobby.stats().sightlineDropped == Build.stats().sightlineDropped`,
`.sightlineCleared == Build.stats().sightlineCleared`, that neither is 0, and the fixture destroyed.
*Verify:* the harness note `task 315: through Lobby.start -- stats.sightlineDropped=12
sightlineCleared=1 (Build: 12 / 1)`.

**3. ...and 0 with the seams nil.** The second half of the same case starts the owner again with
`keepClear = nil`, `sightline = nil`: both counters 0, and the same trunk in the same place is
**still standing** afterwards.

**4. FAIL FIRST, the seam itself.** With `keepClear = world.keepClear` and `sightline =
world.sightline` deleted from `Lobby.tryBuild`'s seam table -- the one line between Karen's cleared
corridor and all twelve trees coming back -- the suite reddened:
`failed [server] lobby_live.spec:1174 Expected value "true" (boolean), got "false" (boolean)`.
Restored, and the gate line above is the restored tree. (Deleting `keepClear` **alone** would not
bite, because `keptClear` also answers true inside the sightline rectangle; the finding named both
lines and both are covered.)

**5. FAIL FIRST, the mirror.** With the two lines `stats.sightlineDropped = built.sightlineDropped` /
`.sightlineCleared` deleted from `tryBuild`:
`failed [server] lobby_live.spec:1178 Expected value "12" (number), got "0" (number)` -- the owner
read 0 while `Build` read 12, which is exactly the boot line printing `0, 0`.

**6. The breakdown, not `> 0` (round 2, finding 1, half two).** `lobby.spec`'s live-build case now
asserts **ring 5, avenue 7, total 12** and `sightlineCleared == 1`. The avenue's share is read
through `Build.avenuePlan` -- the one function that decides it -- handed the trunks really standing,
in the shape `avenue` itself reads them (Models only, by pivot); the ring's share is the remainder,
and the twelve-row `LODGE_TREES` loop above it already shows the grove drops none.
*Verify:* the note `task 315: live build planted 28 trees, 0 in the corridor; sightlineDropped=12
(ring 5 + avenue 7) sightlineCleared=1`.

**7. FAIL FIRST, the hole the finding named.** Round 2: *"deleting `treeLine`'s `+= 1` alone leaves
the avenue's six and the case green"*. With only `treeLine`'s `stats.sightlineDropped += 1` deleted:
`failed [server] lobby.spec:4854 Expected value "5" (number), got "0" (number)`. All three `+= 1`
sites are now separable: `treeLine`'s reddens the ring row, the avenue's reddens the avenue row.

**8. The exact numbers are measurements, and they are exact because the ring is not dice.**
`treeLine` seeds `Random.new(1804)` and draws its jitter once per index **before** every guard, so
the count is the same every build. Design 15.1 predicts the ring by hand at **5..7**; measured 5 --
the bottom of the band, and exactly the five trunks `reviews/task-315/BRIEF.md` measured.

**9. The design's "6 avenue drops" reads 7, and I changed the design in no way.** Every non-gap
`AVENUE.SLOT` is dropped by the corridor, which the pre-existing note *"avenue slots dropped by the
corridor: 7"* has been printing since round 1. The spec asserts the measurement; the design's
one-short arithmetic is a `TASKS.md` row, not an edit this round.

**10. Round 2 caught a false sentence of mine, and here is the correction.** My round-2 request said
*"Deleting any `stats.sightlineDropped += 1`, or the two mirror lines in `Lobby.tryBuild`, now
reddens it"*. **That was wrong in both halves** -- there are three `+= 1` sites against a `> 0`
assertion, and the mirror lines were not read by any case. Claims 4, 5 and 7 above are the same
sentence re-made as three runs.

## What I could not verify

* **`deer_hitbox.spec:659`** (*"calf: the skull at (0.01, 1.50, -1.02) answered nil, wanted head"*)
  failed in **3 of the 5 full-suite runs this session** and passed in the other two, including the
  gate run above. It is not a spec this dispatch names, no deer file is in this branch's diff against
  `origin/main`, and this round touches two lobby spec files only -- so I am not calling it anything
  about this change; it needs a `TASKS.md` row and a control run at the merge-base, which I could not
  take without a branch switch under a live `rojo serve`.
* Everything round 2 listed as unverified is **unchanged and still unverified**: nobody has looked at
  the new east cut face, and there is no hit on a RUNNING target. `TASKS.md` 313a(a) and 313a(o) stay
  open and are not defects of this move.
* `weapon_client.spec:1211` / `:1263` did not fire in any of this round's five runs.

ANSWERED: L-136 -- the ring's exactness was checked before it was asserted (claim 8: fixed seed 1804,
jitter drawn once per index before every guard), and the measured 5 was taken from a run, not from
the design's 5..7 band; the avenue's 7 replaced the design's predicted 6 for the same reason.
ANSWERED: L-127 -- no screen or live-input claim is made this round; round 2's frames are cited as
round 2's, at `c9086a27`, and `src/` has not moved since.
ANSWERED: L-162 -- the three FAIL FIRST lines are quoted from the run that produced them, each naming
the file, line and the two values, and each one break was taken and restored on its own.
