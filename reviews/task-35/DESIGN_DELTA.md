# Task 35 — where the build differs from `docs/design/drive.md`

Milestone 1.7b, the safety penalty and the score screen. Five deviations. **Two of them are
corrections: with the design as written the safety rule would never fire on the case it exists for.**
Each says what the design says, what was built, and why.

---

## 1. `stopAt` is the distance to the AIM POINT, not `report.nearest` — §8.2

**The design:** "`stopAt` is the distance from the muzzle to the nearest impact of that shot… The
weapon already has both numbers at the fire site (`reports` carry `nearest`)."

**Built:** `stopAt = if aimImpact then (aimPoint - muzzle).Magnitude else range`
(`src/server/Weapon/init.luau`, the block that fires `safetySignal`).

**Why.** `reports` are grouped **per damageable target**, and `nearest` is the nearest impact *on that
target*. For a shot that hits nothing damageable there is no report at all, so the design's number does
not exist — and with buckshot (`PELLETS.Buck = 9`, a 1.6° cone) the nearest impact of the whole shot is
whichever pellet clipped the ground first, which at any real range is a few studs from the muzzle. Used
as "where the shot stopped" that number would truncate the shot to nothing and **mask every violation**.
The aim point is where the shot was actually going, it is already computed one line above, and it is the
same quantity for both ammo types.

## 2. `SAFETY_BODY_STUDS = 4` — §8.3

**The design:** the third condition is `t <= math.min(shot.stopAt, config.SAFETY_RANGE_STUDS)`.

**Built:** `reach = math.min(shot.stopAt + config.SAFETY_BODY_STUDS, config.SAFETY_RANGE_STUDS)`.

**Why, and this is the important one.** `t` is measured to the driver's **HumanoidRootPart**, and
`stopAt` is where the pellets **stopped**. When the shot hits the driver the pellets stop on his
*surface*, roughly a stud in front of his root — so `t > stopAt`, and the design's condition judges a
**point-blank shot at a driver harmless**. That is the primary case of the whole rule.

The allowance is the depth of a person and nothing more. Everything the design's own cases require
still holds: its "driver at 50 studs, `stopAt = 40` → none" is rejected by 10 studs, and the case it
exists for (a boar killed at 30 studs with a driver 80 studs behind it, in line) is rejected by 50.
`tests/server/match_safety.spec.luau` asserts both the design's cases and this one.

## 3. `TIE_GAP_STUDS = 2.5` replaces `TIE_OFFSET = CFrame.new(0, 0, 2.5)` — §8.4 item 2, §11.4

**The design:** `character:PivotTo(treeCFrame * TIE_OFFSET)`, "2.5 studs from the tree, facing it".

**Built:** `Body.tiePointFor(tree, from, config)` — the gap is measured from the trunk's **surface**
(`max(Size.X, Size.Z) / 2 + TIE_GAP_STUDS`), the height from its **base**
(`Position.Y - Size.Y / 2 + STAND_HEIGHT_STUDS`), on the side the offender came from, facing the trunk.

**Why.** A part's `Position` is its **centre**. The arena's trees are the four corner pillars,
8 × 24 × 8 (`TestArena.LAYOUT.blocks`), so `treeCFrame * CFrame.new(0, 0, 2.5)` is **inside the trunk
and twelve studs in the air**. The design's number survives as the gap; only what it is measured from
changed. The screenshot is the check the design itself asked for.

## 4. `Anchored` is set BEFORE the pivot, not after — §8.4 items 2 and 3

**The design** lists pivot (2) then `root.Anchored = true` (3), calling the anchor "the belt to
`WalkSpeed`'s braces, so a physics shove from a team-mate cannot drag a tied player around".

**Built:** anchor, then pivot.

**Why.** A character's physics is owned by **its own client**, so a server-side `PivotTo` on an
unanchored root is a suggestion that client can immediately overwrite. Anchoring first makes the pivot
stick. No page states this (`docs/research/2026-09-25-drive.md` §2b G says so plainly); the two-player
run is the evidence that it holds.

## 5. The `release` effect carries no `userIds`, and one thing the design did not have at all — §4.3

**The design:** `{ kind: "release", userIds: { number } }`.

**Built:** `{ kind = "release" }` — the owner releases everyone in its own `tied` table.

**Why.** `Phase` is pure and does not know who is tied; the owner's `tied` table is the one truth
(`mayCarryWeapon` reads it, the snapshot reports it). Putting a second copy in the machine's state
would be two writers of one fact, which is the failure `docs/PROJECT_CONTEXT.md` names three times.
The effect shipped this way in 1.7a already.

**Added, with no line in the design:** a tied player who **respawns** is re-tied to the same tree
(`Match`'s `watchCharacter`). Nothing damages players, but the Reset button exists, and "press Escape,
Reset, and the penalty is over" is not a penalty. `Match.forget` drops the watch and the rope with the
player.

---

## Not a deviation, but worth naming

- `Match.CONFIG.SAFETY_ENABLED` and `Drive.CONFIG.SCOREBOARD_ENABLED` are now `true`; `TIE_SECONDS`
  is implemented (through the pure `Penalty.expired`) even though `TIE_UNTIL_DRIVE_END = true` makes
  it dead in Karen's build, because a config number nothing reads is a lie in a table.
- `ROPE_COLOR` is `RGB(170, 130, 85)`, not the design's `RGB(120, 90, 60)`. The design's own note said
  to check it on screen because `Boar.CONFIG.BODY_COLOR` and `Shotgun.CONFIG.HANDLE_COLOR` both read
  near-black at first try; this was raised for the same reason before the first run, and the
  screenshot shows it reading as warm brown against a grey pillar.
- The score panel is a fixed 16 rows tall (`Drive.CONFIG.SCORE_ROWS_MAX`), so a two-player drive fills
  an eighth of it. Karen's call at the playtest; it is one number.
