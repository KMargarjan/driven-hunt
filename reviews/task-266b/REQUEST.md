# Review request — Task 266b: PROVE TRUE HITS DECIDE SHOTS

Task: 266b
Round: 1
Base: 9acad458 (main, after #245 merged task 266)
Code commit: *(filled in with the harness line it names)*

## PLAN (core quality protocol step 0) — committed before any `src/` edit

**(a) REAL LIFE.** A bullet goes where the sights were when the trigger broke, after its own flight
time. The rifle's .416 at 110–150 studs flies **0.044–0.060 s** (`Ballistics.timeToRange`), so an
animal at 24 studs/s is **1.1–1.4 studs** further on when the bullet arrives. **That — a fraction of
a body length — is the whole lead real shooting asks for at these ranges.**

**(b) MEASURED NOW**, with `HIT_CLAIM` **OFF**, `<runs-dir>/266shot.py`, Forest Test, task 266:

| shot | target | speed | range | server's impact, in the ANIMAL'S OWN frame | where that is |
|---|---|---|---|---|---|
| chest, no lead | `Boar59` | 24.2 | 148.7 | `-1.116, 0.504, **+3.942**` | the rump |
| chest, lead 1.01 | `Boar80` | 24.0 | 108.1 | `1.103, 0.570, **+4.138**` | the rump |

A chest spans about **-1.6 to -0.1** in that frame. So the bullet lands **about four studs behind
the chest** when the real lead is 1.1–1.4 — the error is roughly **three times** the honest lead,
and it is the thing Karen feels.

**AND THE SECOND READING, which is the one this task exists for:** with `HIT_CLAIM` **ON**, no
accepted claim has ever decided a shot. The Reviewer's own round-3 note puts it plainly: *"The
accepted path has never executed, anywhere… the first time the Director lights `HIT_CLAIM` for Karen
is the first execution of that branch in the project's history."* The server's counters would say so
in one number and **cannot be read from a probe** (a probe gets a fresh module cache), which is why
item 1 exists.

**(c) TARGET.**
1. **`claimsAccepted` moves.** Not a tolerance — a count. Three chest shots at a still animal must
   read `accepted +3`, and a forged claim must read `refusedClaimBy["claim-moved"] +1`.
2. **The zone hit is the chest**, on a running animal, aiming AT the chest. The claim's whole purpose
   is that what the shooter saw decides the hit, so the local Z must fall inside the chest's own box
   (about -1.6 to -0.1) instead of +3.9 to +4.1. **The target is the ZONE NAME, which is what Karen
   sees on the hit card** — not a stud figure.

**(d) LEVER.** The counters already exist and are already written; nothing reads them from outside:

```
$ grep -n "claimsAccepted\|refusedClaimBy\|claimWorstStuds" src/server/Weapon/init.luau
202:	claimsAccepted = 0,
204:	refusedClaimBy = {} :: { [string]: number },
212:	claimWorstStuds = 0,
769:	out.refusedClaimBy = table.clone(stats.refusedClaimBy)
1343:		stats.refusedClaimBy[reason] = (stats.refusedClaimBy[reason] or 0) + 1
1414:	stats.claimsAccepted += 1
1415:	stats.claimWorstStuds = math.max(stats.claimWorstStuds, (claim.point - serverPoint).Magnitude)
1744:			stats.refusedClaimBy[key] = (stats.refusedClaimBy[key] or 0) + 1
```

Read those by symbol, not by number. The writers are `judgeClaimFor` (the accept and refuse paths)
and `onFireRequest`'s shape gate. The lever for (c)1 is a **publisher** of those counters; the lever
for (c)2 is `Claim.simulate`'s own frame arithmetic in `src/client/Weapon/Claim.luau`.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument as (b) — `266shot.py`, which prints the
aim, the server's impact in the animal's own frame, and the client's mark — now with the counters
read beside every click through item 1's attribute.

**(f) WHAT I AM FIXING BEFORE I MEASURE, AND WHY IT IS NOT SCOPE CREEP.** Round 3's notes name a
defect that would make item 2 unreadable: in `Claim.simulate`, `blockAt` is the static hit's distance
from `pellet.position` while `hit.distance` is measured from `pellet.position - shift`, so
`hit.distance < blockAt` compares **two different rulers**, by up to `|shift|` (~1.27 studs at the
step cap). At the lead sizes this task is proving — a fraction of a stud — that can refuse a valid
led shot and read exactly like "the claim's frame is wrong", which is the dispatch's own item 3.
Fixing it first is what makes item 2's reading mean anything.
