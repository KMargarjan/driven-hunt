# Task 229 — the role switch: an always-hunter owner can choose to beat, one drive at a time

Task: 229
Round: 2
Base: `963aaa37` (main, after task 228's shop round 2)
Code commit: `SHA_FULL`

Harness, on the clean tree, at that commit:

```
[harness] PASS: 33/33 checks @ SHA_FULL (clean tree) scope=all
```

`[harness2]`: **NOT YET RUN AT THIS COMMIT.** Round 1's code passed it twice at `9d03e712`
(35/35, server 1979/0, shooter 514/0, driver 508/0 -- `<runs-dir>/test2-t229c.log`, `test2-t229d.log`),
but round 2 changes `src/server/Match/`, so the line is needed again for the new commit.
`ESCALATE.md`: `NEEDS DIRECTOR: test2 for task 229 at SHA_SHORT`. The one-player line above was run
at this exact commit so the two will name one sha, which is what `tools/agents.py` requires (L-034).

---

## Round 1's verdict, and what changed

`reviews/task-229/RESULT.md` round 1: **one blocking finding, and it was right.**

**`Match.snapshot`'s `roleOverruled` read the LIVE wish memo** -- but the wish is SPENT by the very
assignment the field is about. `Lobby.wishFor` answers `HUNTER` the moment `Match.assignmentOf`
names a team, so `Lobby.beaterWishes()` is empty within one 10 Hz lobby scan of `enterAssigning`,
while the snapshot is rebuilt on every dispatch for the whole 15 s intermission. From that point
`Roster.overruled`'s guard no longer excluded him, so the man who had just pressed BEATER read
`Objective.CONFIG.TEXT.DriverOverruled` -- **"TEAMS MUST BE EVEN - you beat this drive"** -- for
almost all of it. That is claim 4 and design hazard 8 inverted, and it is the shop's promise being
contradicted by the screen.

**The fix pins the answer to the assignment it is about.** `Match` keeps `seatedWishes`, cleared
when the drive number moves and **only ever added to** -- a mid-drive `join` assigns one man off a
memo that no longer holds the wishes already spent at `enterAssigning`, so replacing it would hand
every earlier wisher back one scan later. The rule is PURE and exported (`Roster.recordSeated`), so
a spec drives the exact sequence that produced the defect.

**The seven non-blocking notes are fixed too, not queued**, because this round was already in the
code. They are claims 12 and 13 below.

Karen, 2026-10-21, verbatim:

> *"we also need to have posibility to choose once you have a card always hunter maybe sometimes I
> want to be a beater we need to find a way to do that"*

Built to `docs/design/role-switch.md` (Architect `PASS` at `afbb7222`, after
`reviews/task-229/BRIEF.md`) and to section 3 of the Designer's `shop2-spec.md`. Note:
`docs/research/2026-10-21-the-role-switch.md`.

**Reproduced first** (rule H, L-028), as a failing assertion before any code:
`match_roster.spec:513 Expected value "Drivers" (string), got "Shooters" (string) instead`, at
commit `cac67619` — the fifth argument is the only input by which an owner could ask to beat, and
there was none.

---

## The claims

**1. An always-hunter owner who asks to beat is seated on the beater side, at every roster size
from 2 to 16, and the sides stay level.** `Roster.assign` takes a FIFTH argument; the wishers take
driver places first, up to `#ids - shooterSlots`, and the privilege and then the rotation fill what
is left, so the split is balanced BY CONSTRUCTION.
*Verify:* `tests/server/match_roster.spec.luau`, `describe("a one-drive BEATER wish")` — the sweep
case, and the mixed sweep `keeps the sides level with any mix of places, wishes and turns`.
`src/server/Match/Roster.luau`, `Roster.assign`.

**2. No wish is the game before this task, by identity.** `beaters` nil or empty makes the
`wishers` list empty and `holders` today's `holders`, so every branch is the line it was;
`Roster.wishedWith(owed, nil)` and `(owed, {})` return `owed` by RAW TABLE EQUALITY.
*Verify:* same spec — `is the game before this task when nobody has asked, at every roster size`
(both the plain and the swap paths, at sizes 2..16) and `hands "owed" back BY IDENTITY`.

**3. A party of one is never honoured, and that needs no guard.** `ODD_PLAYER_TEAM` is `Shooters`,
so `driverSlots` is 0 at one player. The reason is measured, not assumed: `docs/design/bots.md`
fills both sides with rigs but says twice that **no bot shoots** (§1.3, §2), so a solo beater is a
drive in which nothing can be shot.
*Verify:* `match_roster.spec`, `is not honoured for a roster of one, because no bot shoots`;
`match_phase.spec`, `stores nothing: the wish is read on the event and never kept in the state`.

**4. A man who ASKED to beat is never told the balance overruled him.** `Roster.overruled` gains a
third argument; without it a wisher's name would go on the wire and his own Hud would blame the
balance rule for a thing he pressed a button for.
*Verify:* `match_roster.spec`, `never tells a man who ASKED to beat that the balance overruled him`
(and that `overruled(a, always, nil)` is still today's answer). `Match.snapshot`'s `roleOverruled`
passes it.

**5. The wish is owned by `ServerScriptService.Lobby` and written by exactly one function.**
`setRoleWish` is private; its only callers are the door and the scan. It writes the `DHRoleWish`
attribute edge-triggered — `setPadMine`'s discipline — and the stored table holds only the men who
asked to beat.
*Verify:* `src/server/Lobby/init.luau`; `tests/server/lobby_live.spec.luau`,
`writes the attribute once per CHANGE and not once per scan` (`roleWrites` flat across ten scans).
Owner table: `docs/design/role-switch.md` §2.1, and the `GAME_DESIGN.md` lobby row.

**6. THE RESET IS KEYED ON `Match.assignmentOf` AND NOT ON `inDrive`, and that is the correctness
of the feature.** `Lobby.depart` → `Match.enrol` makes a man a participant immediately, while the
assignment that READS the wish happens on a later `Match` step — so a wish cleared on `inDrive`
would be gone before the assignment it was meant to change. The door uses the earlier fact on
purpose (*may he still change his mind*); the reset uses the later one (*has it been spent*).
*Verify:* `lobby_live.spec`, `clears the wish ONE SCAN after the drive has given him a side, and not
before` — the case holds `inDrive = true` with `assignedTeam` nil and asserts the wish SURVIVES,
then seats him and asserts it reads `HUNTER` one scan later and stays cleared. Plus
`keeps the wish of a party that cancelled before any assignment`. The rule itself is pure:
`Lobby.wishFor`, asserted in `tests/server/lobby.spec.luau`.

**7. The door measures every fact itself, and a non-owner is counted apart from a forgery.** Five
verdicts: not started → nil; a word not in `Lobby.ROLE_WISH` (or any other payload) →
`bad-request`; rate-limited → nil; not an owner → `not-an-owner` in `refusedBy`; already in a drive
→ `in-a-drive`. One wire in, none out. Its own rate bucket, so a role ask never costs him his size
pick.
*Verify:* `lobby_live.spec` — the four refusal cases, `has its own rate bucket, so a role ask never
costs him his size pick` (a pad pick in the same 1/10 s still succeeds), and
`refuses every ask when no ownership reader was wired at all`.

**8. The drive reads a frozen memo and nothing else.** `Lobby.beaterWishes()` is rebuilt and never
mutated (`Economy.alwaysHunters`' own device and its stated reason), filled on every event in
`Match.dispatch` beside `owed` and `alwaysShooters`, read in `Phase` and never stored in the state.
*Verify:* `lobby_live.spec`, `hands the drive a FROZEN memo, the same table until something
changes` (writing into it throws); `match_phase.spec`, `stores nothing`; `src/server/Match/init.luau`
(`filled.beaterWishes`), `src/server/Match/Phase.luau` (`Event.beaterWishes`).

**9. Off is the game before this task, and it is asserted at the one boundary that could break it.**
With the shop off nobody owns the row, so `Lobby.setAlwaysHunters` is never wired, `wishFor` answers
nil for everybody, the attribute is never written and no control is built. The DEV place where the
harness runs has **no lobby at all**.
*Verify:* `tests/server/zz_drive_boundary.spec.luau`,
`ran this drive with no role wish in it at all, which is OFF measured (task 229)` — on the REAL
production drive, after a real drive ended. No new flag row (`MAX_FLAGS` is 14 with 14 rows), no
profile field, no `Economy.Store` template change.

**10. Two surfaces, one value, one control, and it is never on both.** The segmented switch is
built and painted ONCE (`ShopPanel.buildRoleSwitch` / `paintRoleSwitch`, the house style's owner)
and PLACED by whichever panel owns the rectangle. Both are TOLD the value from the Hud's one
attribute read per frame. `PadPanel.relayout` becomes the one writer of every rectangle in that
dialog, and the dialog grows **upward** so its bottom edge does not move.
*Verify:* `tests/client/pad_panel.spec.luau` (the block is exactly `BLOCK_PX`; the bottom edges are
equal and the banner still cannot cross it; every row and the hint move by exactly 119; the halves
sit above the block's labels; one `relayout` per change) and `tests/client/shop_panel.spec.luau`
(`switchSurfaceFor` over every combination — *never both*; the owned row 64 → 124 with nothing above
it moved; the phone's 70 px block with three blurb lines still). Measured into the harness report:

```
task229 pad block: dialog 368 -> 487 px, block 119, track 292x38 at y=96, halves 141.5x32,
                   caption y=140, rule y=168, first row y=64 -> 183
task229 shop row:  64 -> 124 px at 1280x720, track 186x34, halves 88.5x28, name y=11,
                   eyebrow y=42, track y=60, caption y=100; phone detail block 70 px, blurb 3 line(s)
```

Every one of those is the Designer's own number (`shop2-spec.md` §3.4, §3.6).

---

## 12. The round-1 fix, and how to check it

**`roleOverruled` is computed against the wishes the assignment was actually made with.**
*Verify:* `src/server/Match/init.luau` -- `seatedWishes` (declared beside `tied`, cleared on a drive
change in `dispatch`, dropped in `Match.forget`, cleared in `Match.start`) and the one line in
`Match.snapshot` that now reads it instead of `world.roleWishes()`. The rule is
`Roster.recordSeated`, pure.
*Verify the rule:* `tests/server/match_roster.spec.luau`,
`still does not name him one scan later, when his wish has been SPENT` -- it records him while the
memo still holds him, then asserts BOTH halves: the empty memo (what the snapshot used to read)
names him, and the record does not. Plus
`records only the wishes an assignment actually SEATED, and only ever adds`, which pins the
mid-drive-join case, the nil/empty case and the in-place contract.
*Verify the off identity:* `tests/server/match_live.spec.luau`,
`leaves roleOverruled absent when no economy is wired` now also asserts `Match.seatedWishes()` is
empty on the REAL running drive and that it hands out a copy.

**What I could NOT do for this finding, stated plainly.** I could not produce a run that is red
before and green after, the way task 220's spec defect was demonstrated. The branch the defect lives
on needs `coinsOn` true -- a wired economy and a lobby -- and `test` / `test2` both REFUSE to start
while any `DHFlag_` override is set, so no harness run can ever have `SHOP` or `COINS` on (design
hazard 14). What the harness does exercise is the nil path: `Roster.recordSeated` is called on every
dispatch of every run with `beaterWishes` nil, and `Match.seatedWishes()` is asserted empty on the
real drive. The ON path's evidence is the pure sequence above plus Karen's Forest Test.

## 13. The seven notes, each fixed at the point it was raised

1. **The role door refuses a payload carrying any field but `role`.** The design asked for it and
   the implementation only read `request.role`, so `{ role = "beater", pad = 1 }` was accepted and
   the extra silently ignored. *Verify:* `src/server/Lobby/init.luau` `Lobby.onRoleRequest`;
   `lobby_live.spec`'s forged list gains two such payloads.
2. **`stats.roleAsks` counts only an ask the game ANSWERED**, not a refusal -- which is what the
   design's verdict table says and what this owner's forged/refused split exists for.
   *Verify:* same file; `lobby_live.spec` asserts `roleAsks == 0` over the forged list.
3. **`PadPanel.stop` nils the eight role fields it was leaving behind**, against its own
   *"nothing on screen, nothing held"*.
4. **The wallet comment is back above `coinsTextFor`**, which it describes.
5. **"THE TEN ROWS" is NINE**, in `src/shared/Lobby/init.luau` and `tests/server/lobby.spec.luau`.
   Nine is what is summed, and 119 was always right.
6. **`shop_panel.spec`'s sender case** asserted `roleBlocked + roleSent == before + 1`, which passed
   whether the ask went out or was refused. It now asserts the refusal AND that nothing was sent.
7. **`hides both surfaces ... and shows one when he does`** now asserts the showing half too.

---

## What I could not verify, and the three deviations

1. **No frame of either surface, and it is not for want of trying.** The DEV place has no lobby, no
   truck pads and no shop counter, so neither control can be put on screen there: the pad dialog's
   visibility is `DHPadFirst` on a pad part that does not exist, and the shop panel opens from the
   keeper's prompt. The StudioMCP thread cannot `require`, so no probe can open a panel either. The
   only place both surfaces exist is Karen's **Forest Test**, and this dispatch says *"DEV only
   (never the Forest Test)"*. So the geometry is asserted arithmetically and off the BUILT
   instances, and printed as the two notes above — which is a stronger statement about pixels than a
   frame, and a weaker one about how it LOOKS. Karen already has the Designer's own picture of both
   surfaces (`<runs-dir>/design/shop2-role.png`); the numbers above are what the build actually
   produced, and every one matches it. **The preview frames are in `ESCALATE.md` as a Director/Karen
   item** (L-011), together with `test2`.
2. **The spec's own two numbers that do not add up, and which one was built.** §3.3 gives the half's
   width as a formula, `(track − 9) / 2`, and its drawing gives 141 for a 288-wide track — the
   drawing forgot the 3 px between the halves. **The formula is what is built** (and expressed as a
   scale, so it holds at any track width); it lands at 141.5 on the pad and 88.5 in the shop row,
   against the drawing's 141 and 90. Named in the code at both ends.
3. **Three places where the build differs from the spec's letter, each with its reason in the code.**
   (a) The pad block sits at the dialog's own `PAD` (14) rather than the spec's `x = 16`, so its
   left edge lines up with the four size rows — which is what the Designer's own picture shows.
   (b) The config row is `Lobby.CONFIG.PADS.PANEL.ROLE` (the spec's name) rather than the design's
   `SWITCH`, and the CONTROL's intrinsic geometry lives in `Shop.CONFIG.PANEL.ROLE_SWITCH` because
   the shop owns the house style.
   (c) The owner's live cases are in `lobby_live.spec` (the spec that starts this owner with fakes)
   rather than `lobby.spec` (the pure one), which the design named; the pure half is in `lobby.spec`.
   (d) **Named after round 1's note 8:** `ShopPanel.layoutFor`'s third argument is a SURFACE STRING
   (`"row"` / `"detail"` / `"none"`) rather than design section 10.8's `switch: boolean?`, and the
   `Layout` field is `switchBlock` rather than `switchDetailHeight`. The string is what makes
   *"never both"* one rule with one answer (`switchSurfaceFor`) instead of a boolean plus a mode
   test at every reader; `layoutFor(w, h)` with no third argument is still exactly today's layout.
4. **The touch is not proved, only the ACTION.** A spec cannot fire `GuiButton.Activated` and the
   harness cannot synthesise a tap, so `sendRoleWish`, `askRole` and `select` are the seams — the
   same limit `PadPanel.press` and `ShopPanel.press` already state.
5. **The ON branch can never run under the harness**, because `test` and `test2` both refuse to
   start while a `DHFlag_` override is set. Every ON claim above is reached BY PARAMETER
   (`setAlwaysHunters(fake)`, `assignedTeam` fake, `Roster.assign(…, wishes)`,
   `setRoleWish(…)`); the production ON path's evidence is Karen's Forest Test.
6. **`tools/agents.py` selftest and `tools/studio_mcp.py` selftest both pass** (rule G); no new spec
   file, so `SCOPE_SPECS` and `BLAST_RADIUS` are untouched.

---

## 11. What the two failed `test2` runs found, and why neither is this branch

**`touch_controls.spec:564` was a TASK 220 spec defect, and it is fixed at the root.** That case has
never run under two players: it arrived with task 220 on 2026-10-21, and the two most recent
`[harness2]` lines in `TASKS.md` are at `1af2cf60` and `449e0120`, where `git cat-file -e` says the
file does not exist. It remembered `Touch.state().carried` and asserted `before.carried + 1`, which
assumes the server does not touch his other Tools while the case runs -- true with one player, false
with two: `zz_tie_to_a_tree.spec` (a two-player-only spec) gets the shooter TIED, and the tie runs
`refreshArmingFor` under `src/server/Match/init.luau`'s own comment, *"mayCarryWeapon now says no, so
the Tool goes"*. The fix pins the count to the LIVE TREE, which is strictly stronger than the delta
it replaces.
*Verify:* `tests/client/touch_controls.spec.luau`,
`sees a horn arrive and leave, without any weapon state changing`. **L-028 is demonstrated, not
asserted:** with the per-frame tell removed from `Hud.renderObjective` the new form fails
(`touch_controls.spec:618`, after its whole 30-frame budget); on healthy code the same note reads
one frame. Logs: `<runs-dir>/l028-probe-t229.log` and `<runs-dir>/test-t229-24e9f231.log`.

**The driver's five failures in run 2 are a starved client, not code. Nothing was changed for them,
and they are recorded as OPEN AND INTERMITTENT rather than as fixed.** Four runs at two shas now:
three green drivers (`278febdb` run 1, reported at 19 s, 508/0; `9d03e712` twice, 508/0) and one red
(`278febdb` run 2, 498 passed / 10 failed, reported at 69 s). `camera_client.spec:648` is not an
input assertion at all -- it is `waitUntil(5, ... lookAtLanded > before)`, *"it does count, once a
frame goes by"* -- so all five are one cause: the driver's client rendered nothing for a stretch,
and `input_driving`'s own `ARRIVE_TIMEOUT` is 45 s (69 s = startup + that timeout). The harness SENT
every step in every run, and the driver's viewport and every other driver note are byte-identical
across the logs; `input_driving.spec` already says in its own words that *"in a two-player local test
this client is a background window rendering at about 15 fps"*. **The two green runs settle only
that it is not a one-off of this branch's code; they do not clear the cause** (L-033), so it stays
open as `TASKS.md` 229e, harness-side.
