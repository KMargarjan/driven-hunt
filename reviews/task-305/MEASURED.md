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

## 3. NOT PROVEN

Walk and trot; the lever and the semi-auto; buckshot; any hunt animal (boar or deer in a drive).
The two halves share `Weapon`'s resolution and the one animal runtime, but nothing here has run
them, and a label proven on one selection does not prove the class.
