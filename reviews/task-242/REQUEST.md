# Review request — Task 242: four fixes from Karen's test

Task: 242
Round: 1
Base: `9fdc5a47` (main, the merge of task 241 — PR #221)
Code commit: `151b259470c8173706133a4cef4e47442087f60e`

```
[harness] PASS: 34/34 checks @ 151b259470c8173706133a4cef4e47442087f60e (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 151b259470c8173706133a4cef4e47442087f60e (clean tree)
```

`test2` was required (`src/server/Match/Roster.luau` is in `TWO_PLAYER_PATHS`) and the Director ran
it **twice**, both clean (server 2031/0, shooter 537/0, driver 531/0). `151b2594` is a PAPERWORK
commit after the last code commit `ec195488`, which git workflow step 4 allows — it only makes the
bound stricter, because the harness ran over everything the code commit holds.

## What changed

Karen, 2026-10-22, verbatim: *"in nex drive I can't select beater but I have this license fix it /
circle is to big and dot is to big / and lever weapon need to reload much faster / also aiming
improved a bit"*. Four fixes, one commit each.

Item 1 was built once and **corrected the same day** on her own clarification, verbatim: *"when you
have a card always hunter technically you can choose to be what you ant eather beater or hunter / so
it give you an option to select othervise by default if you don't have once time you hunter one time
beater"*. The first cut (`65745639`) let the BEATER LICENCE buy the pad switch; it does not.

## Claims, and how to check each

1. **The licence no longer buys the switch, and the revert is total.** `Shop.grantsRoleChoice`,
   `Economy.roleChoosers`, the `Lobby.setRoleChoosers` rename and `Roster.assign`'s non-owner branch
   are gone. *Check:* `git grep -n "roleChoosers\|grantsRoleChoice\|setRoleChoosers" src tests` is
   empty; `git diff 9fdc5a47..HEAD -- src/server/Economy/init.luau
   src/server/ForestTestBoot.server.luau` is empty (byte-identical to main). Archived with both of
   Karen's messages in `backups/2026-10-22_task-242_beater-licence-buys-the-choice.md` (rule 7).

2. **The card gives the choice, and that now includes a solo `1 / 1` drive.** `Roster.assign` keeps
   task 229's `always`-only `wishers` list; the ONE change is `driverSlots`, which is `#ids` at a
   roster of one instead of `#ids - shooterSlots(#ids)`. *Check:* `match_roster.spec`, "IS honoured
   for a roster of one, because there is nothing to balance" — it also asserts that a lone man who
   asks for NOTHING is still a hunter, so the case cannot pass by making everybody a driver.
   `match_phase.spec`'s two solo cases assert the same through `Phase.step`.

3. **The default alternates without a card, and it already did — measured before anything was
   written.** No rule was added. *Check:* `match_roster.spec`, "ALTERNATES every player, drive after
   drive, at one two and four, with and without a stored turn": it drives the real chain
   (`Roster.previousFrom` + `assign`'s swap + `Roster.invert` as the stored turn) for six drives and
   fails if any player repeats a side. Size ONE is the case that could have been wrong, because
   `ODD_PLAYER_TEAM` is `Shooters` and a plain split would hand a lone man that side for ever.

4. **The pad no longer says `NO BEATERS THIS DRIVE`,** because a solo wisher now beats and the
   sentence would be a lie. The row is gone from BOTH tables that carried it
   (`Lobby.CONFIG.PADS.PANEL.ROLE.NOTE_NONE`, `Shop.CONFIG.TEXT.ROLE_SOLO`) and from
   `PadPanel.roleCaptionFor`'s branch. *Check:* `lobby.spec` and `shop_panel.spec` assert both rows
   **absent**; `pad_panel.spec` asserts a party of one now reads `NOTE_SENT`. Archived in
   `backups/2026-10-22_task-242_no-beaters-this-drive.md`.

5. **The red dot's ring is ~31 % smaller and the dot half the size** (`SemiAuto.Geometry`:
   `HOOD_INNER_RADIUS` 0.0617 to 0.0430, `HOOD_WALL` 0.0120 to 0.0074, `DOT_DIAMETER` 0.006 to
   0.003). *Check:* `semiauto.spec`, "THE SIGHT PICTURE", now carries Karen's own two ceilings beside
   task 234's wide bounds — `rimDeg < 18` (shipped 16.4, was 23.8) and `dotDeg < 0.6` (shipped 0.49,
   was 0.98) — so the ring creeping back is a failing test and not the complaint arriving again.

6. **Task 234's alignment is untouched by item 2.** `SIGHT_Y`, `DOT_Z` and `eyeReliefStuds` are the
   same three numbers and nothing moved in z, so the near-plane clearance is where it was (the
   receiver's top 0.085 below the sight line, 0.182 studs away at the frame's bottom edge, against
   Roblox's 0.1 clip). *Check:* those three values in `SemiAuto/Geometry.luau` and
   `src/shared/Viewmodel/poses.json` are unchanged against `9fdc5a47`; `semiauto.spec`'s dot-centre
   and near-plane assertions are untouched and green.

7. **The lever reloads 45 % faster, scaled and not skipped** (`Lever.CONFIG.RELOAD`: 0.40 to 0.22,
   0.42 to 0.23, 0.40 to 0.22; `RELOAD_TOTAL` 2.90 to 1.59; one round 1.22 to 0.67). *Check:*
   `lever.spec`, "reloads through the gate" — the list is still `Break` + five `Load`s + `Close`,
   every wait is over 0.2 s, and the sum equals `RELOAD_TOTAL`. Two relations were rewritten rather
   than deleted, each with its reason in the comment: this gun is no longer slower than the Rigby
   (`lever.spec`), and the semi-automatic is now the slowest reload in the game (`semiauto.spec`).

8. **The lever gets a drawn front bead, and the alignment it sits on was measured first.** Before any
   change, aimed in the Forest Test, the front blade tip and the rear notch shoulders both project to
   (473.5, 392.5) on a 947x785 frame whose centre is (473.5, 392.5) — zero pixels of error. *Check:*
   `lever.spec`, "THE SIGHT PICTURE: both sights land on the screen's centre at aim" (unchanged, and
   it asserts that through the production maths) plus the new case, "draws a BRIGHT front bead on the
   blade": the bead is on `Geometry.beadOffset`, at x = 0, 0.25 to 0.55 degrees at the shipped
   relief, bright against `LOOK.action`, and a row with another sight loses it through task 143's
   `onlyFor` filter — which arrives in this geometry **with** the bead and not before it.

9. **A build where nobody owns anything is unchanged.** *Check:* `match_roster.spec`, "is the game
   before this task when nobody has asked" (every roster size, `beaters` nil and `{}`), and "does not
   read a wish from a man who owns nothing, and he ALTERNATES instead" — the case the first cut had
   inverted, now back, with Karen's ruling recorded in it.

10. **Only paperwork changed after the code commit.** *Check:* `git diff --name-only
    151b2594..HEAD` and `.agent-evidence/paperwork-after-code-commit.txt`.

## What could not be verified

- **Nothing was heard.** The lever's reload is 45 % shorter and its sounds are unchanged; whether the
  shortened sequence still *sounds* like five rounds through a gate is Karen's ear.
- **Nobody judged the look.** Items 2 and 4 are measured (angles, pixels, paired frames at one spot
  with the geometry stashed between them) and looked at by the Builder, but "is the ring now right"
  and "is the bead the right orange" are Karen's.
- **Two queued observations are reported, not fixed** (TASKS.md 242a): the semi-automatic is now the
  slowest reload in the game (2.60 s against 1.59), and open note 227a REPRODUCES — the lever's
  receiver measures (223, 214, 199) in Forest Test sunlight against its own `LOOK.action` of
  (168, 170, 173). That is the upload's `SurfaceAppearance`, not the drawn fallback.
- **`docs/design/role-switch.md` sections 363-370 and its target 3 still state the solo rule this
  task reversed.** The Architect owns that file; the Builder does not write designs. 242a(d).
- **The one-player suite was intermittent at the earlier commit `bba4763d`** (PASS/FAIL/PASS/FAIL
  over four runs of the same commit); at `ec195488` and `151b2594` it has given PASS three times in
  a row. The only failure ever identified was `camera_client.spec:1618` (task 93, hand templates),
  which nothing on this branch touches. 242a(c).
