# Task 298 step B4 — the range's menu, its board and the two remotes

Task: 298
Round: 3
Base: 98df981b (task-298b3-range-gate, step B3's PASS)
Code commit: 6e806ff5e355d2b2024b9e04ad9c84cdd29165c0

```
[harness] PASS: 34/34 checks @ 6e806ff5e355d2b2024b9e04ad9c84cdd29165c0 (clean tree) scope=all
```

`test2` **N/A**: `agents.needs_two_player` over this branch's changed paths returns `[]`.
Round 3 is authorised by the Director (`ESCALATE.md`, 2026-10-27 23:35 UTC).

## Round 2's three findings — fixed, each case RED FIRST at `edc0f24a`

Run with `src/` reverted to `edc0f24a` and these cases present:

```
failed [server] range.spec:1160 Expected value "boar" (string), got "reddeer" (string) instead
failed [server] range.spec:1204 Expected value "0" (number), got "1" (number) instead
failed [client] range_panel.spec:155 Expected value "nil" (nil), got "male" (string) instead
```

1. **A refused request is half applied.** `Range.onRequest` makes TWO passes: every word is judged
   against the request's own other words (a load against this message's gun, a kind against this
   message's species) and **nothing is written until all of them pass**. The client clears
   `picked.kind` on a species pick as it clears `picked.ammo` on a gun pick. Cases: `range.spec` →
   *"writes NOTHING when any word of the request is refused"* (red line 1160); `range_panel.spec` →
   *"clears the kind when the animal changes, so a stale word cannot ride along"* (red line 155).
2. **A hit landed anywhere still counted.** `onHitReported` now needs all three: `Range.mayShoot`,
   a slot `onShotResolved` opened for THIS shot number, and that slot inside
   `CONFIG.HIT_WINDOW_SECONDS` (1.0 — `onShotLanded` publishes the resolution and its reports in one
   frame). The slot is **consumed**, so a second report of one shot changes nothing and the zone
   columns can never disagree with HITS (the round-2 note). Case: *"never counts a hit landed away
   from the mat, however old the last range shot is"* (red line 1204).
3. **The case I claimed did not exist.** It does now, and here is the line:
   `tests/client/range_panel.spec.luau:122` → `it("gives both doors back when he walks off the spot",`.
   It does **not** bite at `edc0f24a` and that is the finding itself: round 1 shipped the CODE
   (`RangePanel.setNear` + `Hud.step`'s caller), not the assertion.

## The range hit — ESTABLISHED, and the cause was a real defect

**`refused=off-stand notice=NOT IN YOUR STAND`**, read off the gun's own `StateChanged` wire
(`<runs-dir>/298b4-shotdiag2.luau`). Design 7.4 lists `off-stand` as *"no change"* on the reasoning
*"no stand → NO AREA MEANS NO RULE"* — **false in any world where a drive is also running**, which
is Karen's: the drive had dealt the lone DEV player a stand 1200 studs away, so every shot from the
mat was outside it. `Range.standOver` is the third composed provider, the shape of the other two:
on the mat, NO AREA (so `Rules.outsideStand` answers false by its own first line); off it, the base
answer untouched. Case: *"hands back NO STAND AREA on the mat, so the drive's stand cannot refuse a
range shot"*, asserted through the shipped `Rules.outsideStand` both ways.

**Live in DEV, `RANGE` on** (`<runs-dir>/298b4-zoneshot.luau`, output `298b4-kill3.out`):

```
trunk Boar7 ... zonesOnly=true
attempt 1: aimed at 1199.1998, 2.1484, 125.0066 (ZoneChest1) | my ray crossed Boar7 | server said nothing
   SHOTS 5   HITS 2   MISS 3  //  HEAD 0  CHEST 2  BODY 0  REAR 0  LEGS 0  MISS 3
attempt 2: no chest part            <- Boar7 is dead; RangeTargets then held Boar8, zoneParts=15
BOARD 7: MISS GAP 3.4 m behind      <- the deliberate miss, 298b4-kill2.out
```

(a) the record's SHOTS rose 1→5; (b) `CHEST` filled from `report.zone`; (c) the target died and was
replaced (`Runtime:takeHit` → the carcass path → a fresh release); (d) the board row above.
Frame `.screenshots/298b4-board-hit.png`, looked at: board reads `SHOTS 5 HITS 2 MISS 3`,
`HEAD 0 CHEST 2 BODY 0 REAR 0 LEGS 0 MISS 3`, `DISTANCE 124 studs (35 m)`,
`PACE STAND pace 0.0 issued 4.5`, `LEAD BALLISTIC 0.00 (0 -- the target stands)`,
`LEAD VIEW <= 0.00`, `MISS GAP --`, `BOAR male at shotgun / Slug`; the menu's six rows lit
BOAR / MALE / STAND / SHOTGUN / SLUG / 125 studs (35 m).

**Two probe faults found on the way, both named rather than worked around:** a freshly equipped gun
has an empty chamber (`Reload` first), and **the client's Camera owner rewrites `CurrentCamera.CFrame`
every frame**, so a `lookAt` written in a probe is gone before the next line — the direction must be
computed and passed in the payload (L-150's family). Neither is a game defect.

## Claims 1–10 are unchanged from round 2 and are not restated.

## Still not proven / not in this round

- The 11.3 live scenario with `RANGE` at its default: **the Director's decision** — the flag stays
  OFF until Karen OKs the flip, and the scenario is queued for it (`ESCALATE.md`).
- LEAD VIEW is always the configured window (printed as a bound): no per-shot measured lag exists on
  the report at this commit.
