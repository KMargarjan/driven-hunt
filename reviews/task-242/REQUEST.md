# Review request — Task 242: four fixes from Karen's test

Task: 242
Round: 2
Base: `9fdc5a47` (main, the merge of task 241 — PR #221)
Code commit: `1fbe670b91cdce68b427fb352eecfd39860e322e`

```
[harness] PASS: 34/34 checks @ 1fbe670b91cdce68b427fb352eecfd39860e322e (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 1fbe670b91cdce68b427fb352eecfd39860e322e (clean tree)
```

`test2` is required (`src/server/Match/Roster.luau` is in `TWO_PLAYER_PATHS`) and was run **twice**,
both clean (server 2031/0, shooter 537/0, driver 531/0 each time — `<runs-dir>/test2-t242c.log`,
`test2-t242d.log`). CI green (run 39799051803); `studio_mcp`, `agents`, `pose` and `privacy_scan`
selftests all pass.

## What changed

Karen, 2026-10-22, verbatim: *"in nex drive I can't select beater but I have this license fix it /
circle is to big and dot is to big / and lever weapon need to reload much faster / also aiming
improved a bit"*. Four fixes.

Item 1 was built once and **corrected the same day** on her own clarification, verbatim: *"when you
have a card always hunter technically you can choose to be what you ant eather beater or hunter / so
it give you an option to select othervise by default if you don't have once time you hunter one time
beater"*. The first cut (`65745639`) let the BEATER LICENCE buy the pad switch; it does not.

**Round 1's blocking finding is fixed, and it was a real defect** — claim 7 below is the one to
re-check hardest.

## Claims, and how to check each

1. **ROUND 1, FINDING 1 — the lever's drawn swing now fits the windows that drive it.** `Mode.step`
   ramps `openTilt` at `dt / config.BREAK_OPEN_SECONDS`, which `Viewmodel.view` fills from
   `data.reload or data.cycle` — one pair per weapon, and this gun has no `reload` block, so
   `poses.json`'s `lever.cycle` drove BOTH sequences. At `closeSeconds` 0.58 inside a 0.22 s reload
   `Close`, the loop was still 37 of its 60 degrees open when the gun became fireable (it already
   overran 19 degrees at 0.40, before this task). *Check:* `lever.cycle.openSeconds` is 0.18 and
   `closeSeconds` 0.20, written through `pose.py`'s own serializer (rule J, `pose.py selftest`
   green); `lever.spec`'s "draws the throw and the close faster than the server performs them, IN
   BOTH LISTS" asserts all four inequalities and that the degrees left open is 0. Harness note:
   `task242 drawn: open 0.18 s vs cycle 0.46 / reload 0.22; close 0.20 vs 0.64 / 0.22`.

2. **The two comments that made the false claim are struck.** *Check:* `Lever.CONFIG.RELOAD`'s block
   and `lever.spec`'s "reloads through the gate" now say what actually drives the swing, with the
   numbers and the round-1 reference. **The cost is stated, not hidden:** inside `CYCLE`'s longer
   0.46 / 0.64 windows the loop reaches full throw in 0.18 s and waits, where it used to be moving
   for nearly the whole cycle. That is a visible change to the throw Karen tuned in task 224, it is
   one line of pose data, and the fix that needs no compromise (a swing time per LIST, which touches
   the camera owner) is queued with these numbers as TASKS.md 242a(e).

3. **The licence does not buy the switch; the card does.** `Shop.grantsRoleChoice`,
   `Economy.roleChoosers`, the `Lobby.setRoleChoosers` rename and `Roster.assign`'s non-owner branch
   are gone. *Check:* `git grep -n "roleChoosers\|grantsRoleChoice\|setRoleChoosers" src tests` is
   empty; `git diff 9fdc5a47..HEAD -- src/server/Economy/init.luau
   src/server/ForestTestBoot.server.luau` is empty. Archived with both of Karen's messages in
   `backups/2026-10-22_task-242_beater-licence-buys-the-choice.md` (rule 7).

4. **The card's choice now includes a solo `1 / 1` drive.** `Roster.assign` keeps task 229's
   `always`-only `wishers` list; the ONE change is `driverSlots`, `#ids` at a roster of one.
   *Check:* `match_roster.spec`, "IS honoured for a roster of one" — it also asserts that a lone man
   who asks for NOTHING is still a hunter, so it cannot pass by making everybody a driver.
   `match_phase.spec`'s two solo cases assert the same through `Phase.step`.

5. **The default alternates without a card, and it already did — measured before anything was
   written, so no rule was added.** *Check:* `match_roster.spec`, "ALTERNATES every player, drive
   after drive, at one two and four, with and without a stored turn": it drives the real chain
   (`Roster.previousFrom` + `assign`'s swap + `Roster.invert` as the stored turn) for six drives and
   fails if any player repeats a side. Size ONE is the case that could have been wrong, because
   `ODD_PLAYER_TEAM` is `Shooters` and a plain split would hand a lone man that side for ever.

6. **The pad no longer says `NO BEATERS THIS DRIVE`.** The row is gone from both tables that carried
   it (`Lobby.CONFIG.PADS.PANEL.ROLE.NOTE_NONE`, `Shop.CONFIG.TEXT.ROLE_SOLO`) and from
   `PadPanel.roleCaptionFor`. *Check:* `lobby.spec` and `shop_panel.spec` assert both rows
   **absent**; `pad_panel.spec` asserts a party of one reads `NOTE_SENT`. Archived in
   `backups/2026-10-22_task-242_no-beaters-this-drive.md`.

7. **The red dot's ring is ~31 % smaller and the dot half the size** (`SemiAuto.Geometry`:
   `HOOD_INNER_RADIUS` 0.0617 to 0.0430, `HOOD_WALL` 0.0120 to 0.0074, `DOT_DIAMETER` 0.006 to
   0.003), **with task 234's alignment untouched** — `SIGHT_Y`, `DOT_Z` and `eyeReliefStuds` are the
   same three numbers and nothing moved in z, so the near-plane clearance is where it was. *Check:*
   `semiauto.spec`, "THE SIGHT PICTURE", carries Karen's two new ceilings beside task 234's wide
   bounds — `rimDeg < 18` (shipped 16.4) and `dotDeg < 0.6` (shipped 0.49); its dot-centre and
   near-plane assertions are untouched and green.

8. **The lever reloads 45 % faster, scaled and not skipped** (`RELOAD` 0.40/0.42/0.40 to
   0.22/0.23/0.22; `RELOAD_TOTAL` 2.90 to 1.59; one round 1.22 to 0.67). *Check:* `lever.spec`,
   "reloads through the gate" — still `Break` + five `Load`s + `Close`, every wait over 0.2 s, sum
   equals `RELOAD_TOTAL`. Two relations were rewritten rather than deleted, each with its reason:
   this gun is no longer slower than the Rigby (`lever.spec`), and the semi-automatic is now the
   slowest reload in the game (`semiauto.spec`).

9. **The lever's front bead, on an alignment measured first.** Before any change, aimed in the
   Forest Test, the front blade tip and the rear notch shoulders both projected to (473.5, 392.5) on
   a 947x785 frame whose centre is (473.5, 392.5) — zero pixels of error. *Check:* `lever.spec`,
   "THE SIGHT PICTURE: both sights land on the screen's centre at aim" (unchanged) plus "draws a
   BRIGHT front bead on the blade": the bead is on `Geometry.beadOffset`, at x = 0, 0.25–0.55 degrees
   at the shipped relief, its colour comes from `Lever.CONFIG.LOOK.bead` (round 1's note: the one
   number Karen must judge belongs in the table she reads), and a row with another sight loses it
   through task 143's `onlyFor` filter, which arrives in this geometry **with** the bead.

10. **A build where nobody owns anything is unchanged, and only paperwork follows the code commit.**
    *Check:* `match_roster.spec`, "is the game before this task when nobody has asked" and "does not
    read a wish from a man who owns nothing, and he ALTERNATES instead"; then `git diff --name-only
    1fbe670b..HEAD` and `.agent-evidence/paperwork-after-code-commit.txt`.

## What could not be verified

- **Nothing was heard.** The reload is 45 % shorter and its sounds are unchanged; whether it still
  *sounds* like five rounds through a gate is Karen's ear.
- **Nobody judged the look.** Items 2 and 4 are measured (angles, pixels, paired frames at one spot
  with the geometry stashed between them) and looked at, but "is the ring now right", "is the bead
  the right orange" and **"does the lever throw still look right now that the loop reaches full throw
  in 0.18 s and waits"** are Karen's. The last one is new in this round and is the cost of fixing
  finding 1.
- **Round 1's non-blocking notes:** the ones that were a comment stating something untrue are fixed
  in place (`sightKind`'s "no piece is filtered on it", `roleCaptionFor`'s "four rows" and its
  duplicated condition, `pad_panel.spec` naming the licence, `match_roster.spec`'s "the case below",
  `lever.spec`'s "0.06 s"). The three stale DESIGNS — `role-switch.md`, `lever-rifle.md`,
  `semiauto-shotgun.md` — are queued as TASKS.md 242a(d): the Architect owns those files and the
  Builder does not write designs.
- **Two observations are reported, not fixed** (242a): the semi-automatic is now the slowest reload
  in the game (2.60 s against 1.59), and open note 227a REPRODUCES — the lever's receiver measures
  (223, 214, 199) in Forest Test sunlight against its own `LOOK.action` of (168, 170, 173). That is
  the upload's `SurfaceAppearance`, not the drawn fallback.
- **The one-player suite was intermittent at the earlier commit `bba4763d`** (PASS/FAIL/PASS/FAIL
  over four runs of the same commit); since `ec195488` it has given PASS four times in a row. The
  only failure ever identified was `camera_client.spec:1618` (task 93, hand templates), which
  nothing on this branch touches. 242a(c).
