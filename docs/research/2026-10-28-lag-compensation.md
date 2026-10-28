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
| rewind amount | `VIEW_LAG_BASE_SECONDS` 0.30 s + ping x 1.0, capped at `VIEW_LAG_MAX_SECONDS` 0.45 s |
| cost | one bounded bounds-query + at most `CLAIM.MAX_TARGETS` extra casts per sub-step |
