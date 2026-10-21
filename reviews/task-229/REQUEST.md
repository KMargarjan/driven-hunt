# Task 229 — the role switch: an always-hunter owner can choose to beat, one drive at a time

Task: 229
Round: 3
Base: `963aaa37` (main, after task 228's shop round 2)
Code commit: `2c45793cdbb691c12fc2060c0fa5dac3b579d8db`

Both gates, on the clean tree, at that one commit:

```
[harness]  PASS: 33/33 checks @ 2c45793cdbb691c12fc2060c0fa5dac3b579d8db (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 2c45793cdbb691c12fc2060c0fa5dac3b579d8db (clean tree)
```

`<runs-dir>/test-t229-r3b.log` (DEV place confirmed in the log: *"Studio has the DEV place open"*,
and both reports *"come from the DEV place (136410205938347)"*) and `<runs-dir>/test2-t229f.log`
(server 1981/0, shooter 515/0, driver 509/0). `2c45793cdbb691c12fc2060c0fa5dac3b579d8db` is a PAPERWORK commit; the last one to touch
`src/`, `tests/` or `tools/` is `929270d8`, and the range between them is `ESCALATE.md`, `TASKS.md`
and this file.

---

## 0. THE FRAMES. The two surfaces were finally photographed, on the player's path

Rounds 1 and 2 were argued without a single picture of either screen, because the DEV place has no
lobby, no truck pads and no shop counter. Round 2's finding 1 -- the control built, placed, painted
and **never rendered** -- is what that cost. The Director opened the Forest Test for this step, so
here is what is actually on screen. **Four frames, each at the real screen size, each inspected.**

| # | File | What it shows |
|---|---|---|
| 1 | `.screenshots/229-frame1-pad-dialog.png` | the truck-pad dialog, owner: `TRUCK 2` / `HOW MANY PLAYERS?` / hairline / **`NEXT DRIVE`** / **HUNTER lit, BEATER muted** / **`A STAND ON THE LINE`** / the rule / the four size rows / the hint |
| 2 | `.screenshots/229-frame2c-beater-lit.png` | the same dialog after asking to beat: **BEATER lit in the blue, HUNTER muted**, caption flipped to **`WALKING THE DRIVE`** |
| 3 | `.screenshots/229-frame3d-shop-row.png` | the shop's owned row: **124 px**, `ALWAYS HUNTER` in the owned green with the **`OWNED` chip up on the name line** and no price line, `NEXT DRIVE`, the switch, `A STAND ON THE LINE` |
| 4 | `.screenshots/229-frame4b-nonowner-pad.png` | a **non-owner's** pad: no eyebrow, no switch, no caption, no rule -- the header straight into the four size rows |

**They match the Designer's `shop2-role.png`** panel for panel: panel 1 against frame 1, the
`chose beater` state against frame 2, panel 2 against frame 3, and *"not owned: nothing"* against
frame 4.

**And the bottom edge really is invariant (design section 14.1), in two photographs rather than in
arithmetic:** frame 1's dialog is 487 px and frame 4's is today's 368, and in both the hint
`STEP OFF THE PAD TO CHANGE YOUR MIND` sits at the same height on the screen. The block grew
upward.

### What the live run proved besides the pictures

Every step below is the real path, with `DHShopTestGrant` money spent through the shop's own remote:

* **the buy is refused away from the counter** -- `refused=too-far` from 765 studs, the server's own
  rule, measured before it was allowed;
* **the purchase works at the counter**: `$13500 -> $11500`, `bought=role.alwayshunter`,
  `ownedRow=true`, and the panel's status line reads `BOUGHT: ALWAYS HUNTER` (frame 3's own
  screenshot carries it);
* **the server writes the attribute the moment he owns it**: `DHRoleWish=hunter`, with no ask at all;
* **the ask is accepted when he is free**: `wish=beater`;
* **the ask is REFUSED once the truck has him** -- `in-a-drive` -- and the caption on his own screen
  reads `ASKED FOR ALREADY`. That is design section 4's check 5 and section 3.7's state 7, live;
* **THE RESET WORKS ON THE REAL PATH.** With `wish=beater` set, the truck took him, and one scan
  after the drive seated him his attribute read **`wish=hunter`** again. The wish was spent by
  exactly one assignment;
* **and he was a HUNTER, from a party of one** -- `team=Shooters` -- which is section 8's rule
  (`driverSlots` is 0 at one player, because no bot shoots) happening in the world rather than in a
  spec;
* **the whole live console carried no `Stack Begin`, no `attempt to`, no `invalid argument` and no
  error line.**

### What those frames are NOT, stated rather than implied

**Frame 3's panel was opened by a probe, not by the prompt.** The shop opens from a
`ProximityPrompt`, and a headless session cannot trigger one -- a synthetic `E` does not reach it
and `InputHoldBegin`/`InputHoldEnd` fired without the panel opening. So that one frame was taken
with the panel's own container set visible from a client probe, and the well scrolled to the row.
**Everything inside it is the real panel** -- the row, its 124 px, the track and the two halves are
where `relayout` put them -- but the opening itself was not photographed. Frames 1, 2 and 4 are the
untouched path: walk onto the pad, the server asks, the dialog opens.

**The Director looked at all four and found one thing, which is QUEUED AND NOT FIXED HERE.** At
487 px the owner's dialog reaches up over the **compass bar** -- the strip shows at its left and
right edges behind the dialog -- where a non-owner's 368 px dialog leaves it clear. That is the cost
of the bottom edge being invariant (section 14.1): the block had to grow upward, because a centred
487 px dialog would put 26 px of its hint band under task 209's loading banner. It is a choice
between two overlaps and wants the Designer's eye, so it is `TASKS.md` 229g rather than a change in
this round.

**The frames do not show the switch being PRESSED.** A spec cannot fire `GuiButton.Activated` and
the harness cannot synthesise a tap, so the asks above went through the same remote the half fires
(`RoleRequest:FireServer({ role = ... })`). What is unproven by a frame is the `Activated`
connection itself -- the same limit `PadPanel.press` and `ShopPanel.press` have always carried.

### The Forest Test was left exactly as it was found

Read first, read again at the end, identical both times:

```
placeId=130094961655666 DHFlag_BOAR_MODEL=true DHFlag_COINS=true DHFlag_DRIVE_BOTS=true
DHFlag_LOBBY=true DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true
```

**No attribute was written.** Play was stopped, the place left in Edit, and its Studio window
closed, so exactly one Studio -- DEV -- was open for the gate above.

**Nothing persistent was written by the purchase.** Each `Play` began with `balanceBefore=13500`
again, so the 2000 spent and the ownership did not survive the session.

---

## Round 2's verdict, and what changed

`reviews/task-229/RESULT.md` round 2: **two blocking findings, both right, and both at the one
thing this task has never been able to photograph.**

**Finding 1 -- the control was never rendered, on either surface.**
`ShopPanel.buildRoleSwitch` built the track `Visible = false` (`buildButton`'s own arrangement for
its progress bar) and **nothing in the repository ever wrote it true**. The two halves live inside
that track, and a `GuiObject` at `Visible = false` is not drawn and takes no input however visible
its parent is -- so on both surfaces the switch was positioned, painted, and hit-tested by the specs
through `ZIndex`, while a player would have seen `NEXT DRIVE` and `A STAND ON THE LINE` around an
**empty gap**. Fixed where it belongs: the one writer of each surface's rectangles -- `relayout`, in
both modules -- now writes the track's `Visible` beside the holder's.

**Finding 2 -- the phone's surface never appeared at all.** `ShopPanel.select` never drove
`relayout`, but the SELECTED item is an input to `switchSurfaceFor`: on a phone the 108 px card has
no room, so the switch rides the selected item's detail pane. `setOpen` relayouts BEFORE it picks a
first row, and `firstId()` prefers a BUYABLE row -- which an owner's `ALWAYS HUNTER` row is not --
so for exactly the man this feature is for the surface was always `"none"`, and tapping his row
changed nothing. `select` now drives the rectangle writer, edge-triggered on the SURFACE.

**Why the specs missed finding 1, which is the worse half.** The round-2 case guarded its own
assertions with `layoutFor(0, 0).mode == "WIDE"` -- and `layoutFor(0, 0)` is a **constant `TALL`**,
because the width clamps up to `MIN_WIDTH` 300, under `WIDE_AT` 520. That block asserted nothing on
any machine. Both the spec and `select` now take the mode from the live screen.

**L-028, demonstrated:** with the three `Visible` writes removed, the new assertions go red --
`pad_panel.spec:674` and `shop_panel.spec:1280`, both *"Expected true, got false"*
(`<runs-dir>/l028-probe-t229-r2.log`). The probe was reverted.

*Verify:* `src/client/Hud/ShopPanel.luau` (`buildRoleSwitch`'s comment, `relayout`'s two
`track.Visible` writes, `select`), `src/client/Hud/PadPanel.luau` (`relayout`'s one);
`tests/client/pad_panel.spec.luau` (`lights the half the SERVER chose` now asserts the TRACK and
both halves are visible, and `draws nothing at all` asserts the track is hidden with its block),
`tests/client/shop_panel.spec.luau` (the same for the row, plus
`drives the rectangle when a SELECTION moves the switch's surface`).

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
