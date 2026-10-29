# Lag compensation: a shot hits what the shooter sees (task 305)

Karen, 2026-10-28, shooting the range: *"aiming is off / when running or trot / with rifle when it
trot or run I need to aim in free space to hit boar correctly ... aiming in nose no hit and I think
it with all weapons fix it"*.

## What the system must do

A shot aimed at the chest of a trotting or running animal, **with only the real ballistic lead**
(`Ballistics.leadStuds` = time of flight x target speed; 0.22 / 0.54 / 1.18 studs for the rifle at
walk / trot / run, as the range board prints), must hit. At 35 m a .416 reaches the boar in ~0.05 s,
so real life asks for ~1.2 studs of lead at a run and nothing more. Today the game asks for that
**plus** ~4.3 studs nobody can see.

## Measured cause (DEV, 2026-10-28, `<runs-dir>/305lag.py`, instrument from task 265 round 3)

Two independent recordings of one part's position against the one shared clock
(`workspace:GetServerTimeNow()`), one on the server and one on the client, best-fit shifted:

| part | owner | mean speed | best-fit shift | residual |
|---|---|---|---|---|
| `Boars.Boar1` (a real boar) | server | 2.55 studs/s | **+0.180 s, client LAGS** | 0.011 studs |
| own `HumanoidRootPart`, pushed | client | 8.69 studs/s | **-0.170 s, client AHEAD** | 0.078 studs |

**The control is MOVING and client-owned, which is what task 265 round 3 lacked** (its only control
stood still, and a motionless part reads 0.000 s under any clock skew). A clock skew biases both
recordings the same way; these two have opposite signs of near-equal size, so the +0.180 s is
replication delay, not skew. It agrees with the 0.178 s task 271 measured in Karen's place from a
refused claim, on a session whose `GetNetworkPing` reads 1.7 ms -- so it is almost all engine
interpolation, not ping.

0.180 s x 24 studs/s (run) = **4.3 studs**, ~1.2 m: exactly the "free space" Karen aims into.

## Re-measured in KAREN'S PLACE (Forest Test, 2026-10-29, task 309, `<runs-dir>/309/zcli.luau` + `zsrv-spawn.luau`)

The 0.180 above is DEV: one boar at 2.55 studs/s, a quiet server. The place Karen plays is not that
place -- the range target runs at 22.5 studs/s at 130 studs with **60 animals** in the world -- so the
same two-sided correlation was run there, on the chest zone the shooter actually aims at and on the
trunk beside it.

| part | mean speed | distance | best-fit shift | sd | p10 / p50 / p90 | residual |
|---|---|---|---|---|---|---|
| `Boar53` trunk | 22.4 studs/s | 130 studs | **+0.2106 s** | 0.0124 | 0.192 / 0.212 / 0.225 | 0.154 studs |
| its `ZoneChest*` centre | 22.5 studs/s | 130 studs | **+0.2057 s** | 0.0181 | 0.184 / 0.205 / 0.227 | 0.233 studs |

93 client frames correlated against 238 server samples over one shared `GetServerTimeNow()`.
**The zone parts lag no more than the trunk**, which refutes the guess that a welded zone replicates
at its own slower rate.

So `FLIGHT_REWIND_BASE_SECONDS` 0.18 under-rewound by 0.0257 s = **0.47 studs mean, 0.95 at p90** at
a run in her place. It was **0.205** from task 309 (a best fit of the drawn chest to the ring) and
is **0.250** since task 309a (the end-to-end residual the fit could not see -- the table row below).

## What this does NOT explain (task 309)

With the bench measuring a chest-centre shot at a RUNNING boar at 20 % and the same shot plus
`Ballistics.leadStuds` at 47 %, the whole measured error budget at 22.5 studs/s is:

| term | mean | worst | instrument |
|---|---|---|---|
| view-lag shortfall (0.2057 - 0.185) | 0.47 studs | 0.95 | the table above |
| gait shift of `ZoneChest` over one window | 0.15 | 0.23 | `<runs-dir>/309/gait.luau` |
| bench camera against its own aim point | 0.29 | 1.08 | `<runs-dir>/309/px2.luau` (1.24 px mean, 4.68 max) |
| slug cone, 0.16 deg full at 130 studs | 0.18 | 0.18 | `Shotgun.CONFIG.SPREAD_FULL_DEG` |
| trajectory over the line of sight, 109-140 studs | 0.03 | 0.04 | closed form, `ZERO_STUDS` 714 |

That sums to ~1.5 studs worst case along a body whose zone boxes run continuously from z -2.53 to
+1.91 with no gap wider than 0.12 studs. **It cannot produce a clean miss, and clean misses are what
the bench reads** -- every missed shot's impact is on the range wall at z = -3350.00. The cause is
therefore NOT in this note's subject and is still unnamed; `ESCALATE.md` (task 309) carries it.

## Sources

1. **Valve, *Source Multiplayer Networking* / Bernier, *Latency Compensating Methods* (GDC 2001)** --
   https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking and
   https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization
   Public wiki, maintained. The canonical answer: the server keeps a short history of every player's
   hitboxes and, when a shot arrives, **rewinds them to the instant the shooter saw** --
   `command_time = packet_time - client_interp`. `sv_maxunlag` caps the rewind at 1.0 s.
   *Well:* server-authoritative, no client trust, one dial. *Badly:* "shot behind cover" -- a
   rewound victim can be hit after taking cover on his own screen.
2. **Overwatch, Ford, *Netcode and Lag Compensation* (GDC 2017 / Blizzard forum posts)** --
   https://www.gdcvault.com/play/1024001/-Overwatch-Gameplay-Architecture-and (talk, free listing).
   Same rewind, with the amount **bounded and derived from the shooter's own measured latency plus a
   fixed interpolation buffer**, and favour-the-shooter stated as a deliberate choice.
   *Well:* names the two terms (ping + interp) separately, which is exactly our split.
   *Badly:* it is a talk, not an implementation; no code to borrow.
3. **Roblox, *Network ownership* and community lag-compensation threads** --
   https://create.roblox.com/docs/physics/network-ownership and
   https://devforum.roblox.com/t/how-to-make-lag-compensation/1398919 (open thread, 2021-, active).
   Roblox renders replicated parts through an interpolation buffer the game cannot read or disable,
   and `Player:GetNetworkPing()` is the only latency a server can see. The community pattern is a
   ring buffer of `{t, CFrame}` per target plus **either** moving the hitbox back for the cast
   **or** translating the ray by the target's displacement. *Well:* the only pattern that works
   inside the engine's constraints. *Badly:* no licensed library; every thread rolls its own.
4. **This repo, task 266-275 (`docs/design/ballistics.md` 5, `reviews/task-271/BRIEF.md`)** -- the
   client-claim half of the same idea, measured and still dark (`HIT_CLAIM` default off).

## The pattern adopted, and why

**Valve server-side rewind, implemented as the ray-translation variant (source 3), inside the cast
seam `Weapon.Flight` already has.** At every sub-step the static world is cast as today, and each
candidate animal is cast **translated by its own displacement over the view lag** -- so the animal
is tested where the shooter drew it, while trees, ground and stands stay exactly where they are.

Borrowed rather than invented (rule 2): the translation-instead-of-teleport trick is already in this
repo, in `Weapon.Claim.simulate`'s target pass (task 266), and the rewind amount is already a
config row, `Shotgun.CONFIG.CLAIM.VIEW_LAG_BASE_SECONDS` + ping x `FLIGHT_CATCHUP_PING_FACTOR`,
with `VIEW_LAG_MAX_SECONDS` as the `sv_maxunlag` cap.

**Why not finish `HIT_CLAIM` instead** (the dispatch offers it): the claim needs the *client* to
simulate and the server to validate, and its refusals on running animals were measured at
0.178 s of time error (task 271). The rewind above makes the server's own flight agree with the
shooter's picture with **no client message at all**, so it also fixes the range (whose board already
prints `LEAD VIEW <= 7.21 studs`), fixes it for every weapon at once, and leaves nothing to trust.
`HIT_CLAIM` stays as it is.

## Numeric targets

| | target |
|---|---|
| extra lead a shooter must add beyond `Ballistics.leadStuds` | **0 studs**, +- 0.63 (one Heartbeat x 38 studs/s, the grid's own quantisation) |
| chest-or-body hits, aiming at the CLIENT-rendered chest + ballistic lead only | **>= 8/10** per pace per gun |
| rewind amount | `FLIGHT_REWIND_BASE_SECONDS` **0.250 s since task 309a** (0.18 was the DEV measurement above; 0.205 was task 309's best fit of the drawn chest to the ring; 0.250 is task 309a's END-TO-END residual -- `DH305Past` minus the drawn trunk on the trigger frame read +1.00/+1.19/+0.90 studs at 0.205 and +0.23/+0.13/+0.00 at 0.250, `<runs-dir>/309a/after-A.txt` against `after-B.txt`, placeId 130094961655666 synced from the test build `driven-hunt-294`, NOT from Karen's own copy. The bench reads the drawn trunk up to one frame LATE, so it UNDER-reports the gap by about 0.4 studs at a run: 0.250 is the UNDER-rewound end and the true zero lies ABOVE it, near 0.254..0.271) + ping x `FLIGHT_CATCHUP_PING_FACTOR` 1.0, capped at `CLAIM.VIEW_LAG_MAX_SECONDS` 0.45 s. **NOT `CLAIM.VIEW_LAG_BASE_SECONDS` (0.30)**: that is a window a sweep searches, where over-estimating is free; this is an amount, and 0.30 would rewind 0.12 s too far -- 2.9 studs at a run, in the other direction |
| cost | one bounded bounds-query + at most `CLAIM.MAX_TARGETS` extra casts per sub-step |

## Amendment, 2026-10-28 (round 1 of the review, and a second Builder's measurement)

**THE CAUSE HAS TWO HALVES AND THIS NOTE FIRST DESCRIBED ONE.** Session `9d5b3ff8`, measuring on the
range mat in Karen's own place, read the opposite sign: the client draws the target **+4.18 studs
AHEAD** of the server (0.174 s in the FUTURE), and `GetNetworkOwner()` reads the PLAYER once he is
on the mat and `SERVER` at 134 studs. `Boar.Body.create` DOES pin the trunk -- it calls `part:SetNetworkOwner(nil)` -- but
`Body.attachVisual` then welds the drawn mesh into the assembly, the assembly is rebuilt, and
ownership reverts to AUTO (`GetNetworkOwnershipAuto()` read true on every live animal in both
places). **So the engine hands a near animal to the nearest player and the server's own copy becomes
the stale one**. An earlier revision of this paragraph named `create` as the missing call; that was
wrong and the call is already there. The required lead therefore FLIPS SIGN with the shooter's distance, which is why it is
unlearnable.

So the rewind above is right only where the SERVER simulates the animal. **Re-pinning the trunk
AFTER `attachVisual`'s weld loop** makes that true at every distance (measured by that session: with it the
same target reads -4.74 studs, 0.213 s in the PAST, one-signed). **Both halves ship or neither
works**, and `AIM_REWIND` is therefore born `default = false` rather than lit: the order is pin the
ownership, re-measure `305lag.py` one-signed at both distances, then flip the flag.
