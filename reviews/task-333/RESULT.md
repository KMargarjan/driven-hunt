PASS (item 2, 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the only thing seen is a DEV
place. The AFTER behaviour (claim 2, 65 -> 0 head-down-while-moving over 53 passes) and the AFTER
frame (claim 10, `333-F1-zoom.png`, `Boar67 clip=trot w=1.00 spd=11.00`) were measured and captured
in DEV Play with the probe `<runs-dir>/333-start.luau`; nobody has watched a range pass in Karen's
Forest Test on this code, and the request says so ("Every number and both frames are from DEV ...
L-014"). The BEFORE is corroborated by her own dispatch wording, but no AFTER exists in her world.
Both frames are descriptions I cannot see; the code can produce what they describe (`Body.clipFor`'s
gait branch answers `trot` for speed 11 with `activity = nil`, since `MODEL.TROT_FROM` 5.13 <= 11 <
`RUN_FROM` 28).

Producer-deletion check (duty (a)), done by reading:
- `boar_calm.spec` "publishes NO activity while it is under an order..." — put the `not
  self:ordered()` term back as it was and the in-loop `expect(intent.activity).to.equal(nil)` fails
  on the FIRST ordered tick: `Brain:_stepCalm` never sets `self._calm` back to nil once drawn (only
  `__index` init does), the preceding loop breaks only when `free.activity ~= nil`, and the case
  itself asserts `intent.state == "IDLE"` under the order. No line of the case survives the
  deletion. The second half (`lapsed == 12` after `LINE.ORDER_SECONDS + 0.5`) kills a fix that
  merely stopped publishing activities. The two `clipFor` assertions are the chain, not the gate.
- `range.spec` "orders the new animal on the very tick it releases it" — `fake.leads` is a cumulative
  log and `fake.spawn` ids are unique (`"fake" .. nextId`), so a lead for a never-seen id can only
  come from the release-tick `order`. Delete `order(trial, from, 0)` from `release` and the first
  order arrives on the next 10 Hz `scan`, six 1/60 ticks after the tick the spec detects
  `targetId ~= lastId`, so `orderedAtBirth` is 0 against `releases >= 3`. Nothing survives.
- Harness line `[harness] PASS: 34/34 checks @ 781221c6... (clean tree) scope=all` names the
  request's `Code commit:`, is "(clean tree)", and `paperwork-after-code-commit.txt` says only
  `TASKS.md` and `REQUEST.md` followed it. selene 0/0, stylua clean, rojo builds.
- Claim 3 verified in the repo: `src/server/Boar/Brain.luau` holds the only `intent.activity =`.

## Notes (non-blocking)
- `src/server/Range/init.luau` / `release` — the new `order(trial, from, 0)` is the one order in this
  file that does not pass the `boars.flying` gate `scan` applies ("THE GUARD `leadIfFree` EXISTS FOR
  ... the drive must not order an animal the Brain is flying"). Unreachable today: `RangeBoot` never
  wires `Weapon.ShotFired` into this runtime's `hearShot`, so `Runtime:spawn`'s spook-at-birth
  branch (`os.clock() - self._lastShotAt <= pace.SPOOK_MEMORY_SECONDS`) cannot fire at the range and
  a newborn has no latched flight. If any world ever feeds a shot to the range runtime, `release`
  must ask `boars.flying` first.
- `src/server/Boar/Brain.luau` / `intent.activity` — the suppression is keyed on `ordered()`, not on
  moving, so it also silences the repertoire for animals that are ORDERED AND STANDING STILL: the
  STAND-pace range target (ordered to `laneCentre` every scan for ever, `desiredSpeed = 0` inside
  `LINE.ARRIVE_STUDS`) and the drive follower that has overrun its station (`ForestTest`'s
  `point, speed = here, 0`). Those draw `idle` where they used to graze, root or smell. Karen's
  sentence is about head-down WHILE MOVING; the narrower gate is `Body.clipFor`'s `walks` branch,
  which lets `digWalk` (own ground 1.901 studs/s) be scrubbed to 11. Queue if she misses the
  standing graze.
- `src/server/Boar/init.luau` / `entry.lastActivity` — a second consequence of the same line: the
  sniff one-shot fires on the `intent.activity ~= entry.lastActivity` edge, so a led animal now never
  sniffs. Head-up and correct for a crossing animal; it also means every member of a drive line is
  sniff-silent for as long as the line holds it. Wider than the task statement.
- `reviews/task-333/REQUEST.md` claim 3 — "`Body.activityClip` / `Body.clipFor` is the only reader"
  is wrong by one: `src/server/Boar/init.luau`'s `lastActivity` edge detector reads
  `intent.activity` too (see the note above). The "only assignment" half is true.
- `reviews/task-333/REQUEST.md`, "What I could not verify" — "24 of 409 after-samples are `idle`
  while moving ... exactly one per pass" cannot hold over 53 passes; at most one per pass.
- `src/server/Range/init.luau` / `order` — the release-tick call adds one per pass to
  `trial.directions[direction]`, `state.stats.leadTos`, and writes `trial.issuedStudsPerSecond` a
  scan earlier. Stats only (`trial.directions` is read by `trialOf`'s clone and `range.spec`, never
  published to a client), but a counter compared across main and this branch is off by one per pass.
- `tests/server/range.spec.luau` — `expect(releases >= 3)` is the only bound on the run; the note
  prints the real count, so this is fine, but a 30 s trot run at `NEXT_PASS_SECONDS` yields many more
  and an exact-ish floor would catch a regression that merely slows releases.
- `docs/design/boar-behaviour.md` §3 state table — the row `IDLE | calm. **Task 117's repertoire
  lives inside it**` now reads false for an ordered animal, which is still IDLE. Not the Builder's
  file (design is the Architect's); for the Director to queue as an amendment, with
  `docs/design/shooting-range.md` §6, which still describes the first order as coming from `scan`.

---
REVIEWER verdict on commit `7904621b5e08ce36e6c99b6893ba92b066af74a0` (round 1) · 2026-11-06 17:51 UTC · session cost $3.62, 49 turns · written by tools/agents.py
