# Task 305 -- the live measurements (Builder session 9d5b3ff8)

The other half of this task (`Weapon.Rewind`) was built by session 5296d523 in the same tree; this
file is the LIVE evidence only, and the two halves are argued in `REQUEST.md`.

Instrument: two probes, both stamping `workspace:GetServerTimeNow()`, so the two sides are compared
on one clock. `<runs-dir>/305/lag-srv.luau` (server) publishes a 45-sample ring of the animal's own
position as an attribute; `<runs-dir>/305/lag3r-cli.luau` (client) builds its own DRAWN history,
interpolates the server ring at each drawn sample's own time, and decomposes the difference into
along-heading / lateral / vertical. `<runs-dir>/305/trial.luau.tpl` fires real `FireRequest`s from
the client VM with the client's own payload (`origin` = camera position), aimed at THIS CLIENT'S
RENDERED `ZoneChest` part plus only the ballistic lead, and counts hits off `HitMarker.OnClientEvent`
with the zone it names; `StateChanged` is read so a refused trigger is never counted as a miss.

## 1. The cause, in numbers

| where | distance | pace | along | lateral | vertical | = view lag |
|---|---|---|---|---|---|---|
| Karen's Forest Test, her range, her build | 126 studs | run 23.5 | **+4.18 studs** | +0.01 | -0.11 | 0.174 s, the client draws it in the FUTURE |
| DEV, the range, player on the mat | 123 studs | run 24.2 | **-4.38 studs** | 0.00 | 0.00 | 0.176 s, the client draws it in the PAST |
| DEV, fleeing drive boars | 25 studs | 17.9 | +2.99 | -0.00 | -0.00 | 0.166 s, FUTURE |

The error is ALONG THE HEADING and nowhere else (lateral and vertical are zero), which is what makes
it a time error and not a geometry one. **Its SIGN flips**, and the sign is decided by who simulates
the animal: `GetNetworkOwner()` read `SERVER` in the DEV rows and `Alhamdulilah824` -- the player --
in Karen's place, with `GetNetworkOwnershipAuto()` TRUE in all of them.

`Body.create` already pins the trunk to the server. `Body.attachVisual` then welds the drawn mesh
into the assembly, the assembly is rebuilt, and ownership goes back to AUTO -- so the engine hands
the animal to the nearest player, the client simulates it, and the SERVER's copy (the one every shot
is cast against) is the stale one. Commit 97d67896 re-pins it after the welds.

Live before/after of that commit, read with `<runs-dir>/305/ownread.luau`:
`auto=true` on the range target and on the drive's boars before; `auto=false owner=SERVER` on both
after.

## 2. The shots. Rifle, the range's RUN pace, mat 1, DEV

Aim = the client's own rendered chest + the ballistic lead alone (`LEAD_T` 0.0476 s = the board's
1.18 studs at 24 studs/s). Hits are `HitMarker` payloads, zone named.

| case | build | hits |
|---|---|---|
| (a) both halves dark | pre-605e1f6d | **0/10** -- 8 flew, all missed |
| (b) ownership pinned live, no rewind | pre-605e1f6d | NOT VALID: 9 of 10 refused `no-ammo` |
| (c) rewind on, ownership not pinned | 605e1f6d | **0/6**, all six flew (the other session's round-1 defect) |
| (d) **both halves on** | 97d67896 + `AIM_REWIND` override on | **10 hits in 11 shots that flew** (5/8 and 5/6 batches; 3 lines are "no live target at pace") |

Zones in (d): chest x6, body x4. The one miss was at 12.5 studs/s; at pace speeds >= 15 studs/s it is
6 for 6. The impacts land 0.02-0.15 studs from the aim point, so the bullet goes where the shooter
pointed. Second gun family, shotgun SLUG at run (`LEAD_T` 0.0714): **4/6**, both full-pace shots in
the chest, two shots produced no impact at all.

Case (c)'s mechanism was caught geometrically rather than inferred (`<runs-dir>/305/geo.luau`): shot
1 crossed (1233.92, 2.17) against a chest at (1233.90, 2.20) -- 0.05 studs -- and carried on to
`Workspace.Range.Berm`. The bullet passed THROUGH the drawn animal.

## 3. The other two paces, both halves on

Same rig, same aim rule, rifle. WALK at `97d67896`: **6/6** (chest x5, rear x1), measured drawn speed
4.4-11.1 studs/s. TROT at `6b0d2271`: **4/4 of the shots that flew** (two lines are "no live target at
pace"), 5.6-9.3 studs/s.

**Those two speeds are honest and they are low.** The range's own target is picked up as soon as it
is moving (the probe fires at > 4 studs/s), so a walk and a trial that begins just after a respawn
are read in the animal's acceleration, not at the pace's own speed -- which also means the whole
demanded lead there is under half a stud, so the hit rate is a weak instrument at those paces. The
discriminating row is RUN, where the lead is 1.1-1.4 studs and the error being cancelled is 4 studs.

Both halves on, every pace: **20 hits in 21 shots that flew** (run 10/11, walk 6/6, trot 4/4).
Both halves dark, run: **0 of 8 that flew**.

## 4. NOT PROVEN

The lever and the semi-auto; buckshot; any hunt animal (a boar or a deer in a drive, rather than the
range's own target). The two halves share `Weapon`'s resolution and the one animal runtime, but
nothing here has run them, and a label proven on one selection does not prove the class.


---

# Section 4 -- CASE (b) MEASURED FOR REAL (Builder session `5296d523`, round 3, 2026-10-28)

The Director's round-3 dispatch: *"MEASURE CASE (b) for real: ownership fix ON, AIM_REWIND OFF,
rifle, run pace then trot then walk, 10 real FireRequests each ... a no-ammo refusal is a harness
fault, not a shot."*

**THE VOID IS CLOSED.** `notice=` is EMPTY on all 30 lines -- not one `no-ammo` -- because
`305/trial.luau.tpl` already asks for the reload after every shot and waits 3.2 s. Instruments:
`305/ft-stand.luau`, `305/ft-pick-run-rifle.luau`, `305/lag-srv.luau` and `305/trial.luau.tpl`,
section 2's own files, driven by `<runs-dir>/305b.py`. **DEV ONLY.**

The ownership fix is confirmed live in every one of the four runs below, off `ft-stand.luau`:
`Boar1 root=Boar1 anchored=false auto=false owner=SERVER dist=117.8-123.9`.

| run | pace | hits | impacts recorded | `impact-drawn` on the shots that landed |
|---|---|---|---|---|
| (b) ownership on, `AIM_REWIND` **off** | run | **0/10** | 7 of 10 | -0.39, -1.73, -2.25, -2.50, -2.61, +1.33, -21.24 |
| (b) | trot | **1/10** (zone `rear`) | 6 of 10 | +0.52, +0.87, +1.27, -0.52, -3.66, -13.28 |
| (b) | walk | **0/10** | **0 of 10** -- see the caveat | none |
| **(d) control, same rig, same session, `AIM_REWIND` on** | run | **7/10** (chest x5, rear x2) | 7 of 10 | -0.83, -0.87, -0.93, -2.33, -2.60, +0.63, +0.98 |

**THE VERDICT IS THE RUN ROW, and it is 0/10 against the control's 7/10 taken minutes later on the
same build with one override changed.** With the rewind off the impacts land BEHIND where the client
DREW the animal -- mean -1.4 studs over the six non-outlier run shots, and the shooter must therefore
aim further ahead than `Ballistics.leadStuds` asks. With it on, `impact-aim` collapses to **+-0.5
studs on 5 of 7**: the bullet goes where he pointed.

**So (b) is NOT >= 8/10 at any pace. `AIM_REWIND` must NOT stay dark.**

**CAVEATS, each a measurement and not a guess.**
- **WALK IS NOT EVIDENCE ABOUT AIM.** All ten shots produced NO impact at all within the probe's
  0.6 s window. The same "no impact" rows appear in the (d) control at speeds 7.0, 9.9 and 11.7
  studs/s -- so it is a RIG artefact that strikes slow targets in BOTH cases equally, not a property
  of the fix. The walk row is reported as 0/10 because that is what it read, and it is **not** read
  as the fix failing at walk.
- L-141 stands: the walk and trot rows do not discriminate (the demanded lead is 0.21-0.63 studs
  there against a ~2-stud error). **RUN is the verdict row.**
- The `impact-srv` column reads `n/a` throughout: `lag-srv.luau`'s ring attribute did not reach the
  client inside the shot window in these runs, so the server-side instant of each impact is NOT
  measured here. `impact-drawn` -- what the client DREW -- is the column the claim rests on, and it
  is this client's own read.
- Two outliers (-21.24 at run, -13.28 at trot) are shots taken as the target reversed at the lane
  end; they are left in the table rather than dropped, and the mean above is quoted without them
  with that said.
