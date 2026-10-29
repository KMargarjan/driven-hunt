"""aim_bench.py -- THE AIM BENCH: one repeatable instrument for "does aiming at what she sees hit".

Karen's core ask (2026-10-24/25) is that aiming at the animal she SEES, plus the real lead, hits --
every gun, every pace. Five sessions measured that with five ad-hoc rigs and the counts disagreed on
ONE build (rifle RUN nose 9/10 in playtest/check305c, 5/9 in check305d, 4/10 on the Builder's rig
where 305b read 9/10). Ten-shot samples of a ~50% aim cannot tell a fix from noise. This is the one
rig, with a sample size, a confidence interval and two self-check cells in every session.

Borrowed, not invented (CLAUDE.md rule 2): task 298's design planned a "shot.py" (B5) and never
built it. Everything here is lifted from rigs that already worked and are cited at each part:
  <runs-dir>/playtest/check305c/trk.luau   the CLIENT tracker on a named point of the DRAWN animal
  <runs-dir>/playtest/check305c/gate.luau  the "aim point is on the viewport centre" gate
  <runs-dir>/305d/trial2.tpl               the drawn-surface support point and the impact decomposition
  <runs-dir>/305run.py                     reading hits from INSTANCE FACTS, never a fresh module
  tools/studio_mcp.py                      the transport, and its Task-6 real-input replay

--------------------------------------------------------------------------------- WHAT IT MEASURES

A CELL is one (weapon, ammo, species, kind, pace, aim point) combination. For each cell the bench
fires N shots (default 30) and prints: N, hits, the zones the server scored, the hit rate with a
95 % Wilson interval, and the mean ALONG / VERTICAL miss of the server's impact against the point
the client was drawing when the trigger went.

**WHY THE DEFAULT IS 30, AND WHAT IT DOES NOT BUY** (round 2, finding 2). It is a chosen cost: at a
true 70 % it halves the 95 % Wilson half-width -- +-24.8 pp at N = 10 against +-15.6 pp at N = 30
(`wilson(7, 10)` against `wilson(21, 30)`, below) -- for about two minutes of clicks per cell. It
does NOT make a 70 % cell and a 40 % cell print disjoint intervals: this bench's own first table has
`nose 21/30 = 70 % (52-83)` against `eye 12/30 = 40 % (25-58)`, which overlap over 52-58. Disjoint
Wilson intervals there need **N = 41**. What separates 70 % from 40 % at N = 30 is a two-proportion
z-test: **z = 2.335, p = 0.0195**. So use 30 to COMPARE two cells, and `--shots 41` when the printed
intervals themselves must be disjoint. The CONTROL / KNOWN-BAD pair is a 60-90 % against a 0-20 %,
which IS disjoint at 30 -- that is why the self-check works at the default.

Two cells run in EVERY session and the table says so if either reads wrong:
  CONTROL   chest centre + Ballistics.leadStuds  -- the textbook aim. Must read HIGH.
  KNOWN-BAD nose + one drawn body length of air  -- clear air. Must read ~0.
An instrument whose known-good and known-bad cells read the same number is not a measurement
(Learning Agent L-141); `summarise()` marks the table `INSTRUMENT SUSPECT` when they do.

------------------------------------------------------------------------------ HOW A SHOT IS FIRED

Through the REAL client input path and no other: a `mouseButtonClick` sent with StudioMCP's
`user_mouse_input` into the Play client, which is the same VirtualInputManager route the harness's
own Task-6 input replay uses. That reaches `UserInputService` -> `ContextActionService` ->
`DrivenHunt.Weapon.Fire` -> `Weapon.Input.fire`, which is the ONE firer of `FireRequest` in the
client (`src/client/Weapon/Input.luau` header). The bench never builds a `FireRequest` payload --
that is what every earlier rig did, and a hand-built payload can differ from the click's.

THE CLICK PROOF (`aim_bench.py ray`) IS A NEGATIVE CONTROL, not a geometry argument.
`src/client/Weapon/Input.luau` is the ONLY writer of a VALUE to the attribute `DHClaimWhy` in the
whole repo, inside `Input.fire` itself, immediately before `FireRequest:FireServer`. Cleared, with
no click sent, it stays `nil`; one real click sets it. So the click ran the live `Input.fire`.
`Input.fire` sends `{origin = camera.CFrame.Position, direction = camera.CFrame.LookVector.Unit}`
and the resident reads that same pair on the frame the attribute changed -- which IS the frame the
trigger went, not the frame the host asked for it.
The impact's distance from that ray is PRINTED AND ASSERTS NOTHING: the server flies from
`Ballistics.boreOrigin` along `Ballistics.launchDirection` (elevated for the gun's zero), not from
the camera along the camera ray, so a stud or two at 130 studs is the shipped ballistic.

----------------------------------------------------------------------------- HOW A SHOT IS AIMED

The camera is held on a named point of the animal AS THE CLIENT DRAWS IT, through
`src/client/Camera/TestLook.luau` (attribute `DHTestLook`) -- the Studio-only hook the camera owner
already has, and the route L-120 proved works in Play. A probe may not call `Camera.lookAt`: an
`execute_luau` require hands back a FRESH module copy and would aim a camera nobody looks through
(`tools/studio_mcp.py`, "Staging a scenario").

The points, all computed from the DRAWN parts in the client datamodel, with travel = the trunk's own
smoothed horizontal velocity:
  chest       centre of the drawn ZoneChest* parts
  chestfront  frontmost surface point of the drawn chest parts along travel
  nose        frontmost surface point of the drawn ZoneHead* parts along travel
  eye         a Bone matching "^[Ee]ye" if the mesh has one, else the drawn head parts' upper-front
              quadrant (centre + 1/4 of their height up, + 1/4 of their length along travel).
              The row says which of the two was used, every shot.
  ahead       nose + one drawn body length along travel -- the KNOWN-BAD cell, clear air
A `+lead` suffix adds `Ballistics.leadStuds(shot, distance, speed)` along travel.

---------------------------------------------------------------------- HOW A RESULT IS READ BACK

From what the LIVE GAME WROTE, never from a probe's module state (memory:
studio-mcp-execute-luau-single-line -- a require through execute_luau returns a fresh module whose
counters are 0):
  hit / zone   the `HitMarker` and `ShotLanded` remotes the server fired at this client
  the card dot the `Dot` frames the live `Hud.HitCard` actually DREW, read off the instances
  the impact   `ShotLanded`'s own impact position, which is post-rewind -- the server's answer
  the trace    `ServerStorage.DHLastHits`, the `HitLog` ring (zone, local offset, uv, dist)
  the offset   TWO WAYS, because one was not enough (task 310): `along`, the strike minus the aim
               point along the SMOOTHED TRAVEL direction, and `back`, ring-z minus the aim point's
               own body-axis coordinate -- both ends divided down by the trunk's CFrame, the frame
               the zone itself was read in. They are the same quantity, so a cell where they differ
               by more than `OFFSET_DISAGREEMENT_STUDS` on one shot prints OFFSET DISAGREEMENT
               rather than averaging it away. That is how a RUN cell read "30/30, mean along -0.52"
               while its own zone split said `rear 5`: a strike whose ring sat at z=+1.42 with the
               aim at z=-0.41 is 1.83 studs back, not 0.78.
The resident writes one row per shot into a LocalPlayer attribute, so the host reads instance facts.

------------------------------------------------------------------------------------------- USAGE

  python tools/aim_bench.py selftest
      Every pure rule here, with no Studio and no network. Runs in CI.

  python tools/aim_bench.py cells
      The cell grammar and the point names.

  python tools/aim_bench.py ray [--studio <id>]
      The click proof: one real click, the camera ray and the server's impact on the same frame.

  python tools/aim_bench.py run <cell> [<cell> ...] [--shots N] [--out FILE] [--place PLACEID]
      Run the cells in order. Needs the Forest Test in PLAY with the player standing on the range
      mat. The CONTROL and KNOWN-BAD cells are appended automatically unless they are already named.

A CELL is  weapon[:ammo]/pace/point[+lead][~species[.kind]]  -- for example
  rifle/run/nose            shotgun:SLUG/run/nose         rifle/run/chest+lead
  rifle/trot/chestfront     rifle/run/nose~reddeer.stag   rifle/run/ahead

Exit codes: 0 ran, 1 a cell could not be run, 2 no Forest Test in Play.

THE BENCH NEVER WRITES A `DHFlag_*` ATTRIBUTE and never clears one (CLAUDE.md rule K): it reads the
place's flags once and prints them beside the table, so a reader knows which build the numbers are
from. The only attributes it writes are its own `DHBench*` and the camera owner's `DHTestLook`.
"""

import argparse
import json
import math
import os
import re
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools"))

FOREST_TEST_PLACE = "130094961655666"

# The aim points, in the order the table prints them. The value is the word the resident branches on.
POINTS = ("chest", "chestfront", "nose", "eye", "ahead")

# The two self-check cells (L-123, L-141). Appended to every run that does not already name them.
CONTROL_POINT = "chest+lead"
KNOWN_BAD_POINT = "ahead"

# A known-bad cell that scores above this is not clear air, and a control below this is not a
# textbook aim. Either one trips `INSTRUMENT SUSPECT` on the table.
KNOWN_BAD_MAX_RATE = 0.20
CONTROL_MIN_RATE = 0.50


# ------------------------------------------------------------------------------ the cell grammar
#
# Kept pure and tested by `selftest`, because every number in the table is addressed by one of
# these and a typo in a cell spec must fail before Play, not after thirty clicks.


class CellError(ValueError):
    pass


class Cell:
    """One (weapon, ammo, species, kind, pace, point, lead) combination."""

    def __init__(self, weapon, ammo, species, kind, pace, point, lead):
        self.weapon = weapon
        self.ammo = ammo
        self.species = species
        self.kind = kind
        self.pace = pace
        self.point = point
        self.lead = lead

    @property
    def key(self):
        """The cell's name in the table and in the JSON -- stable, and its own spec."""
        gun = self.weapon if self.ammo is None else "%s:%s" % (self.weapon, self.ammo)
        tail = "%s+lead" % self.point if self.lead else self.point
        animal = self.species if self.kind is None else "%s.%s" % (self.species, self.kind)
        return "%s/%s/%s~%s" % (gun, self.pace, tail, animal)

    @property
    def is_control(self):
        return self.point == "chest" and self.lead

    @property
    def is_known_bad(self):
        return self.point == KNOWN_BAD_POINT

    def __repr__(self):
        return "Cell(%s)" % self.key


# weapon[:ammo] / pace / point[+lead] [~species[.kind]]
_CELL_RE = re.compile(
    r"^(?P<weapon>[A-Za-z0-9_.\-]+)(?::(?P<ammo>[A-Za-z0-9_.\-]+))?"
    r"/(?P<pace>[A-Za-z]+)"
    r"/(?P<point>[A-Za-z]+)(?P<lead>\+lead)?"
    r"(?:~(?P<species>[A-Za-z0-9_]+)(?:\.(?P<kind>[A-Za-z0-9_]+))?)?$"
)

PACES = ("stand", "walk", "trot", "run")


def parse_cell(text, default_species="boar", default_kind=None):
    """One cell spec -> a Cell. Raises CellError with the reason, never a bare match failure."""
    if not isinstance(text, str) or text.strip() == "":
        raise CellError("empty cell spec")
    m = _CELL_RE.match(text.strip())
    if m is None:
        raise CellError("cannot read %r -- want weapon[:ammo]/pace/point[+lead][~species[.kind]]" % text)
    pace = m.group("pace").lower()
    if pace not in PACES:
        raise CellError("%r: pace %r is not one of %s" % (text, pace, ", ".join(PACES)))
    point = m.group("point").lower()
    if point not in POINTS:
        raise CellError("%r: point %r is not one of %s" % (text, point, ", ".join(POINTS)))
    lead = m.group("lead") is not None
    if point == KNOWN_BAD_POINT and lead:
        # `ahead` is already a body length of air; a lead on top of it measures nothing new and
        # would quietly stop being the known-bad cell the table checks itself against.
        raise CellError("%r: the known-bad point %r takes no +lead" % (text, KNOWN_BAD_POINT))
    return Cell(
        weapon=m.group("weapon"),
        ammo=m.group("ammo"),
        species=(m.group("species") or default_species),
        kind=(m.group("kind") if m.group("kind") is not None else default_kind),
        pace=pace,
        point=point,
        lead=lead,
    )


def parse_cells(specs, default_species="boar", default_kind=None):
    return [parse_cell(s, default_species, default_kind) for s in specs]


def with_self_checks(cells, weapon="rifle", pace="run", species="boar", kind=None):
    """Append the CONTROL and KNOWN-BAD cells unless the list already carries one of each.

    L-123: they are part of the instrument, not an optional extra, so the caller cannot forget them.
    """
    out = list(cells)
    if not any(c.is_control for c in out):
        out.append(parse_cell("%s/%s/%s" % (weapon, pace, CONTROL_POINT), species, kind))
    if not any(c.is_known_bad for c in out):
        out.append(parse_cell("%s/%s/%s" % (weapon, pace, KNOWN_BAD_POINT), species, kind))
    return out


# ------------------------------------------------------------------------------- the arithmetic


def wilson(hits, n, z=1.959963984540054):
    """The 95 % Wilson score interval for a proportion -> (low, high), both in 0..1.

    Wilson and not normal-approximation: at n = 30 and p near 0 or 1 the normal interval runs off
    the end of the scale and would print a negative hit rate.
    https://en.wikipedia.org/wiki/Binomial_proportion_confidence_interval#Wilson_score_interval
    """
    if n <= 0:
        return (0.0, 0.0)
    p = hits / float(n)
    denom = 1.0 + z * z / n
    centre = (p + z * z / (2.0 * n)) / denom
    half = (z / denom) * math.sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n))
    return (max(0.0, centre - half), min(1.0, centre + half))


def mean(values):
    vals = [v for v in values if v is not None and not (isinstance(v, float) and math.isnan(v))]
    if not vals:
        return None
    return sum(vals) / float(len(vals))


def _ring_z(row):
    """The body-axis (z) coordinate of the struck point in the animal's own frame, or None.

    `HitLog`'s ring line carries `local=(x,y,z)` divided down by the report's OWN frame (task 308),
    so z is where along the body the bullet struck: negative toward the snout, positive toward the
    rump. It is the one number that says which PART was hit without trusting the zone word.
    """
    raw = row.get("ringlocal")
    if not isinstance(raw, str):
        return None
    bits = raw.split("|")
    if len(bits) != 3:
        return None
    try:
        return float(bits[2])
    except ValueError:
        return None


# How far the two offset columns may disagree on one shot before the cell says so, in studs.
# 0.5 BECAUSE THE CHEST'S HALF-SPAN IS 0.87 STUDS, measured on the running boar
# (<runs-dir>/310/zonemap.luau: chest local z [-1.38 .. +0.36]): a disagreement above 0.5 can move
# a shot's verdict from chest to body, which is the verdict Karen reads off the card.
OFFSET_DISAGREEMENT_STUDS = 0.5


def _back(row):
    """The strike's rearward offset FROM THE AIM POINT, in the animal's own frame, or None.

    `ringz - aimz`: both are body-axis coordinates divided down by the trunk's CFrame, so the
    difference is directly comparable with `-along`. `along` alone cannot be: it is measured from
    the aim point along the SMOOTHED TRAVEL direction, while the ring is measured from the trunk
    centre along the trunk's own axis (task 310).
    """
    ringz = _ring_z(row)
    aimz = row.get("aimz")
    if ringz is None or not isinstance(aimz, float) or aimz != aimz:
        return None
    return ringz - aimz


def offset_disagreement(row, limit=OFFSET_DISAGREEMENT_STUDS):
    """Do this row's two offset columns disagree by more than `limit` studs? Pure.

    `back` is positive toward the rump and `along` is positive down the heading, so the two agree
    when `back == -along`. `None` for a row that carries only one of them -- an absent number is
    not a disagreement.
    """
    back = _back(row)
    along = row.get("along")
    if back is None or not isinstance(along, float) or along != along:
        return None
    return abs(back - (-along)) > limit


def summarise(results):
    """[{cell, rows}] -> the table rows plus the instrument verdict.

    `results` rows are the dicts `parse_rows` produces. Pure, so `selftest` drives every branch.
    """
    table = []
    controls, known_bads = [], []
    control = None
    known_bad = None
    for entry in results:
        cell = entry["cell"]
        rows = entry["rows"]
        # A ROW THE SERVER NEVER ANSWERED IS NOT A SHOT (round 1, finding 4). `answered` is false
        # when no HitMarker, no ShotLanded and no notice arrived -- a click the gun swallowed. It is
        # excluded from N rather than counted as a miss, and the cell is flagged.
        unanswered = [r for r in rows if r.get("answered") is False]
        rows = [r for r in rows if r.get("answered") is not False]
        n = len(rows)
        hits = sum(1 for r in rows if r.get("hit"))
        low, high = wilson(hits, n)
        zones = {}
        for r in rows:
            z = r.get("zone")
            if r.get("hit") and isinstance(z, str) and z not in ("", "-", "nil"):
                zones[z] = zones.get(z, 0) + 1
        row = {
            "cell": cell.key if isinstance(cell, Cell) else str(cell),
            "n": n,
            "hits": hits,
            "rate": (hits / float(n)) if n else 0.0,
            "ci": (low, high),
            "zones": zones,
            "along": mean([r.get("along") for r in rows]),
            "up": mean([r.get("up") for r in rows]),
            # THE THREE INSTRUMENT COLUMNS (task 309a). `pastgap` is how far along travel the
            # server tested the animal from where the client drew it (`DH305Past` minus the drawn
            # trunk). `ringz` is the body-axis coordinate, in the animal's OWN frame, of the point
            # the bullet struck -- read out of the `HitLog` ring, which is the part that was hit and
            # not the zone word beside it (rule L). `rings` is how many rows had a ring line at all:
            # an empty ring is the instrument failing, not the animal missing.
            "pastgap": mean([r.get("pastgap") for r in rows]),
            "ringz": mean([_ring_z(r) for r in rows]),
            # THE STRIKE'S REARWARD OFFSET FROM THE AIM POINT, in the ring's own frame (task 310),
            # and how many rows' two offset columns disagree by more than
            # `OFFSET_DISAGREEMENT_STUDS`. Never averaged away: the disagreement IS the finding.
            "back": mean([_back(r) for r in rows]),
            "backdisagree": sum(1 for r in rows if offset_disagreement(r) is True),
            "backs": sum(1 for r in rows if _back(r) is not None),
            "rings": sum(1 for r in rows if r.get("ringlocal")),
            "ringdisagree": sum(
                1
                for r in rows
                if r.get("ringzone") and r.get("zone") and r.get("ringzone") != r.get("zone")
            ),
            "unanswered": len(unanswered),
            "role": ("CONTROL" if getattr(cell, "is_control", False) else ("KNOWN-BAD" if getattr(cell, "is_known_bad", False) else "")),
        }
        table.append(row)
        if row["role"] == "CONTROL":
            controls.append(row)
        elif row["role"] == "KNOWN-BAD":
            known_bads.append(row)

    notes = []
    # EVERY control and known-bad cell is checked, not just the last one named.
    for row in table:
        if row["unanswered"]:
            notes.append(
                "NOT A MEASUREMENT: %s had %d click(s) the server never answered (no HitMarker, no "
                "ShotLanded, no notice) -- a swallowed trigger, not a miss. They are excluded from N, "
                "so this cell's N is %d of the %d clicks sent."
                % (row["cell"], row["unanswered"], row["n"], row["n"] + row["unanswered"])
            )
        if row["n"] == 0 and row["unanswered"]:
            notes.append(
                "NO SHOT IN %s REACHED THE SERVER AT ALL -- 0 %% here is a reading about the TRIGGER, "
                "not about the aim. Do not carry it forward as a fact about the game." % row["cell"]
            )
    control = controls[-1] if controls else None
    known_bad = known_bads[-1] if known_bads else None
    for extra in controls[:-1] + known_bads[:-1]:
        notes.append("MORE THAN ONE %s CELL RAN; %s is not the one the verdict below checks."
                     % (extra["role"], extra["cell"]))
    if control is None:
        notes.append("NO CONTROL CELL RAN -- the table is not self-checked.")
    elif control["n"] == 0:
        notes.append("CONTROL cell fired 0 shots -- the table is not self-checked.")
    elif control["rate"] < CONTROL_MIN_RATE:
        notes.append(
            "INSTRUMENT SUSPECT: the CONTROL cell (chest + Ballistics.leadStuds) read %d/%d = %.0f %%, "
            "below %.0f %%. A textbook aim that misses means the rig, the pace or the build is wrong, "
            "not the cells under test." % (control["hits"], control["n"], 100 * control["rate"], 100 * CONTROL_MIN_RATE)
        )
    if known_bad is None:
        notes.append("NO KNOWN-BAD CELL RAN -- nothing proves the rig can miss.")
    elif known_bad["n"] == 0:
        notes.append("KNOWN-BAD cell fired 0 shots -- nothing proves the rig can miss.")
    elif known_bad["rate"] > KNOWN_BAD_MAX_RATE:
        notes.append(
            "INSTRUMENT SUSPECT: the KNOWN-BAD cell (a body length of clear air) read %d/%d = %.0f %%, "
            "above %.0f %%. An input that must not work is working, so a high rate anywhere in this "
            "table may be the rig and not the game."
            % (known_bad["hits"], known_bad["n"], 100 * known_bad["rate"], 100 * KNOWN_BAD_MAX_RATE)
        )
    if control is not None and known_bad is not None and control["n"] and known_bad["n"]:
        # L-141: the two self-check cells must READ DIFFERENTLY. Equal rates mean the rig answers
        # the same whatever it is pointed at, which is exactly the unfailable 305-series rig.
        c_low, c_high = control["ci"]
        k_low, k_high = known_bad["ci"]
        if not (c_low > k_high or k_low > c_high):
            notes.append(
                "INSTRUMENT SUSPECT: CONTROL %d/%d and KNOWN-BAD %d/%d have OVERLAPPING 95 %% intervals "
                "(%.0f-%.0f %% vs %.0f-%.0f %%). The rig does not distinguish a good aim from clear air, "
                "so no row below it is a measurement."
                % (
                    control["hits"], control["n"], known_bad["hits"], known_bad["n"],
                    100 * c_low, 100 * c_high, 100 * k_low, 100 * k_high,
                )
            )
    return table, notes


def render(table, notes, header=None):
    """The one table, as text. Pure."""
    out = []
    if header:
        out.extend(header)
        out.append("")
    widths = [max(28, max([len(r["cell"]) for r in table] + [4]))]
    fmt = "%-{0}s %4s %5s %7s %-15s %8s %8s %8s %8s %8s %6s  %-9s".format(widths[0])
    out.append(
        fmt
        % ("cell", "N", "hits", "rate", "95% interval", "along", "back", "up", "pastgap",
           "ring-z", "ring", "role")
    )
    out.append("-" * (widths[0] + 90))
    for r in table:
        low, high = r["ci"]
        out.append(
            fmt
            % (
                r["cell"],
                r["n"],
                r["hits"],
                "%.0f%%" % (100 * r["rate"]),
                "%.0f%% - %.0f%%" % (100 * low, 100 * high),
                "--" if r["along"] is None else "%+.2f" % r["along"],
                "--" if r.get("back") is None else "%+.2f" % r["back"],
                "--" if r["up"] is None else "%+.2f" % r["up"],
                "--" if r.get("pastgap") is None else "%+.2f" % r["pastgap"],
                "--" if r.get("ringz") is None else "%+.2f" % r["ringz"],
                "%d/%d" % (r.get("rings", 0), r["n"]),
                r["role"],
            )
        )
        if r.get("backdisagree"):
            out.append(
                " " * 4
                + "OFFSET DISAGREEMENT on %d of %d row(s): `back` (the strike's rearward offset "
                "from the aim point, in the ring's own frame) and `-along` differ by more than "
                "%.1f studs. `along` is measured along the SMOOTHED TRAVEL direction from the aim "
                "point; `back` is ring-z minus aim-z, both divided down by the trunk's CFrame. "
                "Trust `back`: it is the frame the zone was read in."
                % (r["backdisagree"], r.get("backs", 0), OFFSET_DISAGREEMENT_STUDS)
            )
        if r.get("ringdisagree"):
            out.append(
                " " * 4
                + "RING DISAGREES WITH THE MARKER on %d row(s): the zone the HitMarker named is not "
                "the zone the struck part carries." % r["ringdisagree"]
            )
        if r["unanswered"]:
            out.append(" " * 4 + "NOT FIRED: %d click(s) the server never answered, excluded from N"
                       % r["unanswered"])
        if r["zones"]:
            order = sorted(r["zones"].items(), key=lambda kv: (-kv[1], kv[0]))
            out.append(" " * 4 + "zones: " + "  ".join("%s %d" % (k, v) for k, v in order))
    out.append("")
    out.append("along / up are the SERVER's impact minus the point the CLIENT was drawing, in the")
    out.append("animal's own frame, read on the frame `Input.fire` ran: +along is down its heading")
    out.append("(behind the aim point), +up is above. `--` means no shot in the cell produced an")
    out.append("impact, so there was nothing to measure against.")
    out.append("")
    out.append("back is THE SAME OFFSET IN THE RING'S OWN FRAME (task 310): ring-z minus the aim")
    out.append("point's own body-axis coordinate, both divided down by the trunk's CFrame.")
    out.append("+back is toward the rump, so back and -along are the same quantity measured two")
    out.append("ways; where they differ by more than %.1f studs the cell says so, because along" % OFFSET_DISAGREEMENT_STUDS)
    out.append("uses the smoothed travel direction and the zone was read in the trunk's.")
    out.append("")
    out.append("pastgap is DH305Past minus the drawn trunk, along travel: how far from what the")
    out.append("shooter saw the server tested the animal (+ = ahead of it). ring-z is the struck")
    out.append("point's body-axis coordinate in the animal's OWN frame, out of HitLog's ring")
    out.append("(- = toward the snout, + = toward the rump). ring is how many rows had a ring line")
    out.append("at all -- 0/N means the instrument wrote nothing, which is never a fact about aim.")
    for n in notes:
        out.append("")
        out.append("** " + n)
    if not notes:
        out.append("")
        out.append("Self-check: CONTROL and KNOWN-BAD both read as they must.")
    return "\n".join(out)


# ------------------------------------------------------------------------- the per-shot row format
#
# The resident writes one line per shot into a LocalPlayer attribute and the host parses it here.
# A flat `key=value` line rather than JSON because a Roblox attribute is a plain string and the
# parse must be total: an unreadable field becomes None and the row still counts as a shot.

_NUM = re.compile(r"^-?\d+(?:\.\d+)?$")


def parse_row(line):
    """One `k=v k=v` row -> a dict. Unknown keys are kept; unreadable numbers become None."""
    row = {}
    for token in str(line).split(" "):
        if "=" not in token:
            continue
        k, v = token.split("=", 1)
        if v in ("nan", "-nan", "nil", ""):
            row[k] = None
        elif v in ("true", "false"):
            row[k] = v == "true"
        elif _NUM.match(v):
            row[k] = float(v) if "." in v else int(v)
        else:
            row[k] = v
    return row


_TRACE = re.compile(
    r"#(?P<n>\d+)\s+t=(?P<t>\S+?)s\s+(?P<kind>\S+)\s+id=(?P<id>\S+)\s+zone=(?P<zone>\S+)\s+"
    r"local=\((?P<lx>[^,]+),(?P<ly>[^,]+),(?P<lz>[^,)]+)\)\s+uv=\((?P<u>[^,]+),(?P<v>[^,)]+)\)"
)


def parse_trace(line):
    """One `HitLog` ring line -> the ring columns of a bench row (task 309a).

    The line's shape is `HitLog.Shape.traceLine`'s own, and the parse is total: a line that does not
    match leaves the columns None, so a shot with no ring line reads as "the instrument wrote
    nothing" and never as a zero.
    """
    m = _TRACE.search(str(line or ""))
    if m is None:
        return {"ringzone": None, "ringlocal": None, "ringuv": None, "ringid": None, "ringn": None}
    return {
        "ringzone": m.group("zone"),
        "ringlocal": "%s|%s|%s" % (m.group("lx"), m.group("ly"), m.group("lz")),
        "ringuv": "%s|%s" % (m.group("u"), m.group("v")),
        "ringid": m.group("id"),
        # THE LINE'S OWN `#n` (round 1, finding 3). `HitLog` numbers every line it writes, so a
        # shot is credited with a ring line only when that number is one this cell has not already
        # seen -- which no comparison of the text can decide.
        "ringn": int(m.group("n")),
    }


def ring_credit(line, seen):
    """Should this ring tail be credited to the shot just fired? Pure (round 1, finding 3).

    `ServerStorage.DHLastHits` PERSISTS -- across cells, across runs, and across any drive hit --
    and the bench only ever reads it. So "the tail changed since the previous shot" is not enough:
    the first shot of every cell after the first would be credited with the previous cell's last
    line whenever it missed, which is exactly the unfailable reading the ring exists to kill.
    A line counts only when its own `#n` is one `seen` has not already recorded; `seen` is seeded
    from the ring as it stands BEFORE the cell's first shot.
    """
    trace = parse_trace(line)
    n = trace.get("ringn")
    if n is None or n in seen:
        return None
    return n


def ring_indices(blob):
    """Every `#n` in a ring blob, for seeding `seen`. Unreadable lines are skipped, not guessed."""
    out = set()
    for raw in str(blob or "").splitlines():
        n = parse_trace(raw).get("ringn")
        if n is not None:
            out.add(n)
    return out


def parse_rows(blob):
    """The attribute's whole text -> [row]. Blank and non-row lines are dropped, not guessed at."""
    rows = []
    for line in str(blob or "").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        row = parse_row(line)
        if "i" in row:
            rows.append(row)
    return rows


# ------------------------------------------------------------------------------- the Luau resident
#
# Injected ONCE per session. It is a resident and not a per-shot probe for the reason every earlier
# rig learned the hard way: an `execute_luau` call gets a FRESH module cache, so it cannot see the
# live game's state -- but an Instance, an attribute and a remote connection are shared. The
# resident owns the connections and the tracker; the host only reads attributes and sends clicks.
#
# A GENERATION COUNTER, not a boolean: re-injecting must not leave the previous install's Heartbeat
# loop and remote listeners running beside the new one, double-counting every shot.

RESIDENT = r"""
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local gen = (tonumber(me:GetAttribute("DHBenchGen")) or 0) + 1
me:SetAttribute("DHBenchGen", gen)
me:SetAttribute("DHBenchRows", "")
me:SetAttribute("DHBenchMode", "chest")
me:SetAttribute("DHBenchLead", false)
me:SetAttribute("DHBenchAim", "")
me:SetAttribute("DHBenchRay", "")
me:SetAttribute("DHBenchShot", 0)
me:SetAttribute("DHBenchReset", 0)
me:SetAttribute("DHBenchSpd", 0)
me:SetAttribute("DHTestLookOff", nil)

local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local remotes = ReplicatedStorage:WaitForChild("Shotgun"):WaitForChild("Remotes")

local function mine() return (tonumber(me:GetAttribute("DHBenchGen")) or 0) == gen end

-- ---------------------------------------------------------------- the drawn points (check305c)
local function targetFolder() return workspace:FindFirstChild("RangeTargets") end
local function animal()
  local f = targetFolder()
  if f == nil then return nil end
  for _, m in ipairs(f:GetChildren()) do
    local r = if m:IsA("BasePart") then m else m.PrimaryPart
    if r ~= nil and not r.Anchored then return r, m end
  end
  return nil
end
local function partsNamed(root, pat)
  local t = {}
  for _, d in ipairs(root:GetDescendants()) do
    if d:IsA("BasePart") and string.match(d.Name, pat) then t[#t + 1] = d end
  end
  return t
end
-- The frontmost CORNER of a set of boxes along dir -- the drawn surface, not the centre
-- (305d/trial2.tpl: the nose BONE sits 0.28-1.82 studs below the boxes at a run).
local function support(parts, dir)
  local best, bd = nil, -1e9
  for _, p in ipairs(parts) do
    for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do
      local w = p.CFrame:PointToWorldSpace(Vector3.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2))
      local d = w:Dot(dir)
      if d > bd then bd, best = d, w end
    end end end
  end
  return best
end
local function centreOf(parts)
  if #parts == 0 then return nil end
  local s = Vector3.zero
  for _, p in ipairs(parts) do s += p.Position end
  return s / #parts
end
local function spanOf(parts, dir)
  local lo, hi = 1e9, -1e9
  for _, p in ipairs(parts) do
    for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do
      local w = p.CFrame:PointToWorldSpace(Vector3.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2))
      local d = w:Dot(dir)
      if d < lo then lo = d end
      if d > hi then hi = d end
    end end end
  end
  if lo > hi then return 0 end
  return hi - lo
end
local function eyeBone(model)
  for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("Bone") and string.match(d.Name:lower(), "^eye") then return d end
  end
  return nil
end

-- ------------------------------------------------------------------- what the live game wrote
local shotIndex, rows = 0, {}
local lastZone, lastImpact, lastNotice, markers = "", nil, "", 0
remotes:WaitForChild("HitMarker").OnClientEvent:Connect(function(p)
  if not mine() then return end
  markers += 1
  lastZone = tostring(if type(p) == "table" then p.zone else p)
end)
remotes:WaitForChild("ShotLanded").OnClientEvent:Connect(function(p)
  if not mine() then return end
  local im = if type(p) == "table" then p.impacts else nil
  if type(im) == "table" and im[1] ~= nil then
    local f = im[1]
    lastImpact = if typeof(f) == "Vector3" then f else (f :: any).position
  end
end)
remotes:WaitForChild("StateChanged").OnClientEvent:Connect(function(p)
  if not mine() then return end
  if type(p) == "table" then
    local n = p.refused or p.notice
    if n ~= nil then lastNotice = tostring(n) end
  end
end)
-- THE BOARD THE SERVER PUSHED, kept verbatim so the host can print the picked value and the
-- board's own word on the SAME line (verdict V298: the mismatch is the finding).
local rangeRemotes = ReplicatedStorage:FindFirstChild("Range")
rangeRemotes = rangeRemotes and rangeRemotes:FindFirstChild("Remotes")
if rangeRemotes and rangeRemotes:FindFirstChild("RangeBoard") then
  rangeRemotes.RangeBoard.OnClientEvent:Connect(function(p)
    if not mine() then return end
    local rec = if type(p) == "table" then p.record else nil
    if type(rec) == "table" then
      me:SetAttribute("DHBenchBoard", string.format(
        "species=%s kind=%s pace=%s weapon=%s ammo=%s shots=%s hits=%s",
        tostring(rec.species), tostring(rec.kind), tostring(rec.pace),
        tostring(rec.weapon), tostring(rec.ammo), tostring(rec.shots), tostring(rec.hits)))
    end
  end)
end
-- THE CARD'S DOT AS THE CLIENT DREW IT: the `Dot` frames `Hud.HitCard` actually put on the
-- silhouette, read off the instances, never re-derived here.
local function readDot()
  local gui = me:FindFirstChild("PlayerGui")
  local card = gui and gui:FindFirstChild("HitCard", true)
  if card == nil then return nil, nil end
  local best
  for _, d in ipairs(card:GetDescendants()) do
    -- NOT the lead legend (`Hud.HitCard` marks that one `Lead = true`): it sits at the same place
    -- on every card and would read as the same dot for every shot.
    if d:IsA("Frame") and d.Name == "Dot" and d:GetAttribute("Lead") ~= true then best = d end
  end
  if best == nil then return nil, nil end
  return best.Position.X.Scale, best.Position.Y.Scale
end
-- THE CARD IS DRAWN AFTER THE MARKER AND CLEARED WHEN IT HIDES (`BoarArt.clearDots`), so the dot
-- is polled for rather than read once: a single read a quarter-second after the hit found nothing
-- on three hits out of three (measured here, 2026-10-28).
local function cardDot()
  local t0 = os.clock()
  repeat
    local u, v = readDot()
    if u ~= nil then return u, v end
    RS.Heartbeat:Wait()
  until os.clock() - t0 > 1.2
  return nil, nil
end

-- ----------------------------------------------------------------------------- the tracker
-- Writes `DHTestLook` every Heartbeat -- `src/client/Camera/TestLook.luau` is the camera owner's
-- own Studio hook and the ONLY route a probe may steer the live camera by (L-120).
local aimPoint, aimDir, aimSpeed, aimSource = nil, Vector3.zero, 0, "?"
local SPEED_WINDOW = 0.15
task.spawn(function()
  local hist, smooth = {}, nil
  while mine() do
    RS.Heartbeat:Wait()
    local root, model = animal()
    if root == nil then aimPoint = nil continue end
    local now = os.clock()
    -- OVER A WINDOW, NOT A FRAME. A one-frame difference on an animated trunk read 49.7 studs/s on
    -- a target the server was carrying at 24, which both mis-gates the shot and mis-sizes the lead.
    -- 305d/trial2.tpl hit the same thing on the snout and widened its own difference to 4 frames.
    hist[#hist + 1] = { t = now, p = root.Position }
    while #hist > 1 and now - hist[1].t > SPEED_WINDOW do table.remove(hist, 1) end
    local span = now - hist[1].t
    if span > 1 / 240 then
      local v = (root.Position - hist[1].p) / span
      aimSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
      if aimSpeed > 1 then
        smooth = Vector3.new(v.X, 0, v.Z).Unit
      end
    end
    me:SetAttribute("DHBenchSpd", aimSpeed)
    local dir = smooth or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
    aimDir = dir
    local heads = partsNamed(model, "^ZoneHead")
    local chests = partsNamed(model, "^ZoneChest")
    if #chests == 0 then aimPoint = nil continue end
    local chestMid = centreOf(chests)
    local mode = tostring(me:GetAttribute("DHBenchMode"))
    local p, src = nil, mode
    if mode == "chest" then
      p = chestMid
    elseif mode == "chestfront" then
      p = support(chests, dir)
    elseif mode == "nose" then
      p = (#heads > 0 and support(heads, dir)) or support(chests, dir)
    elseif mode == "eye" then
      local bone = eyeBone(model)
      if bone ~= nil then
        p, src = bone.TransformedWorldCFrame.Position, "eye:bone"
      elseif #heads > 0 then
        local c = centreOf(heads)
        local up = spanOf(heads, Vector3.yAxis)
        local len = spanOf(heads, dir)
        p, src = c + Vector3.new(0, up / 4, 0) + dir * (len / 4), "eye:quadrant"
      end
    elseif mode == "ahead" then
      local nose = (#heads > 0 and support(heads, dir)) or support(chests, dir)
      -- THE DRAWN MODEL's span along travel, not the root part's: the docstring says "one drawn
      -- body length" and the trunk part is shorter than the animal (round 1, note).
      local bodyParts = { root }
      for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then bodyParts[#bodyParts + 1] = d end
      end
      local body = spanOf(bodyParts, dir)
      if nose ~= nil then p, src = nose + dir * body, string.format("ahead:%.2f", body) end
    end
    if p ~= nil and me:GetAttribute("DHBenchLead") == true then
      local cam = workspace.CurrentCamera
      local origin = if cam then cam.CFrame.Position else p
      local tool = me.Character and me.Character:FindFirstChildOfClass("Tool")
      local wid = tool and (Weapons.idForToolName(tool.Name) or tool.Name)
      local row = wid and Weapons.row(wid)
      local ammo = tool and (tool:GetAttribute("Chambered") or tool:GetAttribute("Ammo"))
      local shot = row and Ballistics.shotFor(row, ammo or (row.AMMO_KINDS and row.AMMO_KINDS[1]))
      if shot ~= nil then
        local lead = Ballistics.leadStuds(shot, (p - origin).Magnitude, aimSpeed)
        p = p + dir * lead
        src = src .. string.format("+lead%.2f", lead)
      else
        src = src .. "+lead?"
      end
    end
    aimPoint, aimSource = p, src
    if p ~= nil then
      me:SetAttribute("DHTestLook", string.format("%.3f,%.3f,%.3f", p.X, p.Y, p.Z))
    end
  end
end)

-- -------------------------------------------------------------- the gate and the shot watcher
-- A shot is noticed by the `DHBenchShot` attribute the HOST bumps immediately before it sends the
-- click, so the row carries the aim point of THAT frame and not of the frame the answer arrived in.
task.spawn(function()
  local seen = tonumber(me:GetAttribute("DHBenchShot")) or 0
  local cleared = tonumber(me:GetAttribute("DHBenchReset")) or 0
  while mine() do
    RS.Heartbeat:Wait()
    -- ONE CELL'S ROWS ONLY. Emptying the attribute from the host was not enough: THIS list is the
    -- thing that gets rewritten into it, so a second cell republished the first cell's shots and
    -- the two self-check cells counted every earlier cell's hits as their own.
    local wantClear = tonumber(me:GetAttribute("DHBenchReset")) or 0
    if wantClear > cleared then
      cleared, shotIndex, rows = wantClear, 0, {}
      me:SetAttribute("DHBenchRows", "")
    end
    local want = tonumber(me:GetAttribute("DHBenchShot")) or 0
    if want > seen then
      seen = want
      -- ON THE FRAME THE CLIENT ACTUALLY FIRES, not the frame the host asked it to (round 1,
      -- finding 2). `bump` and `click` are two separate StudioMCP round trips, so the click lands
      -- at least one request after the bump and the aim has moved. `Input.fire` writes
      -- `DHClaimWhy` immediately before `FireRequest:FireServer`, so clearing it here makes the
      -- next non-nil value that attribute's own signal that the trigger went -- and THAT frame is
      -- where the ray and the aim point are read. The bench is therefore a second writer of
      -- `DHClaimWhy`, and it only ever writes nil: only `Input.fire` sets a value.
      me:SetAttribute("DHClaimWhy", nil)
      local waitFrames = 0
      repeat
        RS.Heartbeat:Wait()
        waitFrames += 1
      until me:GetAttribute("DHClaimWhy") ~= nil or waitFrames > 120
      local fired = me:GetAttribute("DHClaimWhy") ~= nil
      local cam = workspace.CurrentCamera
      local origin = cam.CFrame.Position
      local direction = cam.CFrame.LookVector.Unit
      -- `Input.fire`'s OWN TWO EXPRESSIONS, read on the frame it ran.
      me:SetAttribute("DHBenchRay", string.format("%.4f,%.4f,%.4f|%.5f,%.5f,%.5f",
        origin.X, origin.Y, origin.Z, direction.X, direction.Y, direction.Z))
      local aim, dir, spd, src = aimPoint, aimDir, aimSpeed, aimSource
      -- WHERE THE CLIENT DREW THE ANIMAL ON THE FRAME THE TRIGGER WENT (task 309a). The third of
      -- the three numbers the per-shot row must carry: the server's tested frame (`DH305Past`),
      -- this one, and the part the bullet struck (`DHLastHits`, read host-side).
      local troot = animal()
      local drawn = if troot ~= nil then troot.Position else nil
      -- THE AIM POINT'S OWN BODY-AXIS COORDINATE, in the animal's frame, on the fire frame (task
      -- 310). `along` is measured from the AIM POINT and `ring-z` from the TRUNK CENTRE, so the two
      -- were printed side by side with different origins; this is the one number that makes
      -- `ringz - aimz` the strike's rearward offset from the aim in the ring's own frame.
      -- Same frame the ring uses: `HitLog.frameOf` divides down by the trunk's CFrame.
      local aimz = 0 / 0
      if troot ~= nil and aim ~= nil then aimz = troot.CFrame:PointToObjectSpace(aim).Z end
      local before = markers
      lastImpact, lastNotice = nil, ""
      local t0 = os.clock()
      repeat RS.Heartbeat:Wait() until lastImpact ~= nil or markers > before or os.clock() - t0 > 1.2
      task.wait(0.25)
      local hit = markers > before
      -- DID THE SERVER ANSWER AT ALL (round 1, finding 4)? A click the gun swallowed -- a bolt or
      -- lever cycle, an empty chamber, a refusal -- produces no marker, no `ShotLanded` and
      -- sometimes a notice. Counted as a MISS it is indistinguishable from clear air, which is
      -- exactly the unfailable reading this instrument exists to kill.
      local answered = hit or lastImpact ~= nil or lastNotice ~= ""
      local impact = lastImpact
      local along, up, across = 0 / 0, 0 / 0, 0 / 0
      if impact ~= nil and aim ~= nil then
        local gap = impact - aim
        along = gap:Dot(dir)
        up = gap.Y
        across = (gap - dir * along - Vector3.new(0, up, 0)).Magnitude
      end
      -- THE TWO TENSES THE SERVER PUBLISHED FOR THIS CAST (task 309a, `Weapon.castWithRewind`).
      -- Read AFTER the answer, so the attributes have replicated; `nil` when the cast never rewound.
      local function vec3(raw)
        if type(raw) ~= "string" then return nil end
        local x, y, z = string.match(raw, "([^,]+),([^,]+),([^,]+)")
        if x == nil then return nil end
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
      end
      local past, pres, pastAt = nil, nil, nil
      if troot ~= nil then
        past, pres = vec3(troot:GetAttribute("DH305Past")), vec3(troot:GetAttribute("DH305Pres"))
        pastAt = tonumber(troot:GetAttribute("DH305At"))
      end
      -- THE GAP THAT SETTLES IT, along travel: the server tested the animal this far from where the
      -- client drew it. Positive = the server tested it AHEAD of what the shooter saw.
      local pastgap = 0 / 0
      if past ~= nil and drawn ~= nil then pastgap = (past - drawn):Dot(dir) end
      local du, dv = cardDot()
      shotIndex += 1
      local function f(x) return if x ~= x then "nan" else string.format("%.3f", x) end
      rows[#rows + 1] = string.format(
        "i=%d mode=%s src=%s hit=%s answered=%s fired=%s frames=%d zone=%s spd=%.2f dist=%.1f "
          .. "along=%s up=%s across=%s aimz=%s aim=%.2f|%.2f|%.2f impact=%s cardu=%s cardv=%s "
          .. "drawn=%s past=%s pres=%s pastat=%s pastgap=%s notice=%s",
        shotIndex, tostring(me:GetAttribute("DHBenchMode")), tostring(src), tostring(hit),
        tostring(answered), tostring(fired), waitFrames,
        if hit then lastZone else "-",
        spd, if aim then (aim - origin).Magnitude else 0 / 0,
        f(along), f(up), f(across), f(aimz),
        if aim then aim.X else 0 / 0, if aim then aim.Y else 0 / 0, if aim then aim.Z else 0 / 0,
        if impact then string.format("%.2f|%.2f|%.2f", impact.X, impact.Y, impact.Z) else "nil",
        if du then f(du) else "nil", if dv then f(dv) else "nil",
        if drawn then string.format("%.2f|%.2f|%.2f", drawn.X, drawn.Y, drawn.Z) else "nil",
        if past then string.format("%.2f|%.2f|%.2f", past.X, past.Y, past.Z) else "nil",
        if pres then string.format("%.2f|%.2f|%.2f", pres.X, pres.Y, pres.Z) else "nil",
        if pastAt then string.format("%.3f", pastAt) else "nil",
        f(pastgap),
        if lastNotice ~= "" then lastNotice else "-")
      me:SetAttribute("DHBenchRows", table.concat(rows, "\n"))
    end
  end
end)

return string.format("bench up gen=%d", gen)
"""

# The gate: the aim point must project onto the viewport centre and the animal must be at pace,
# or the click measures a different shot from the one the cell names (check305c/gate.luau).
GATE = r"""
local me = game:GetService("Players").LocalPlayer
local cam = workspace.CurrentCamera
local raw = me:GetAttribute("DHTestLook")
if cam == nil or type(raw) ~= "string" then return "NOTREADY nolook" end
local x, y, z = string.match(raw, "([^,]+),([^,]+),([^,]+)")
local p = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
local sp = cam:WorldToViewportPoint(p)
local cx, cy = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
local dx, dy = math.abs(sp.X - cx), math.abs(sp.Y - cy)
local f = workspace:FindFirstChild("RangeTargets")
local root
for _, m in ipairs(f and f:GetChildren() or {}) do
  local r = if m:IsA("BasePart") then m else m.PrimaryPart
  if r ~= nil and not r.Anchored then root = r break end
end
if root == nil then return "NOTREADY notarget" end
local spd = tonumber(me:GetAttribute("DHBenchSpd")) or 0
local ch = me.Character
local tool = ch and ch:FindFirstChildOfClass("Tool")
if dx < %PX% and dy < %PX% and spd >= %MINSPD% and sp.Z > 0 then
  return string.format("READY px=%.1f,%.1f spd=%.2f dist=%.0f held=%s centre=%.0f,%.0f",
    dx, dy, spd, sp.Z, tostring(tool and tool.Name), cx, cy)
end
return string.format("NOTREADY px=%.1f,%.1f spd=%.2f held=%s", dx, dy, spd, tostring(tool and tool.Name))
"""


def camera_write_free(src):
    """Does this Luau text assign to a `.CFrame`? (round 2, finding 1.)

    The bench must reach the camera ONLY through `Camera.TestLook`; `Camera.Rig` is the one writer
    of `workspace.CurrentCamera` in the repo. The old guard looked for the literal
    `"CurrentCamera.CFrame ="`, which the realistic write does not contain: `RESIDENT`'s own idiom
    is `local cam = workspace.CurrentCamera`, so a second writer reads `cam.CFrame = ...`.
    Whitespace is squashed first, so `cam.CFrame=cf` and a double-spaced `=` are caught too.
    """
    return ".CFrame=" not in "".join(str(src).split())


def oneline(src, **kw):
    """Strip a Luau block to one line for execute_luau (`305run.py`'s own helper).

    StudioMCP's `execute_luau` takes the code as one JSON string; comments and blank lines go
    first so a `--` cannot swallow the rest of the script once the newlines are gone.
    """
    out = []
    for raw in src.splitlines():
        line = raw.strip()
        if not line or line.startswith("--"):
            continue
        out.append(line)
    joined = " ".join(out)
    for k, v in kw.items():
        joined = joined.replace("%" + k + "%", str(v))
    return joined


# ------------------------------------------------------------------------------------ the driver


class Bench:
    def __init__(self, place=FOREST_TEST_PLACE, viewport_px=12.0):
        import studio_mcp

        self.studio = studio_mcp.Studio()
        self.place = place
        self.viewport_px = viewport_px
        self.studio_id = self._find_play_client()

    def _find_play_client(self):
        """The Play client of the named place, and NOT a silent fall back to DEV.

        L-055 / Rule C: an explicit studio_id can fall back to the editor when the target drops off
        the listing for one call, which is how a measurement ends up taken in the wrong place. So
        the id is resolved by place id AND the choice is confirmed by asking that id for its own
        `game.PlaceId` before anything else runs.
        """
        # THE LISTING IS FLAKY and the flake costs a whole run (task 310): `list_roblox_studios`
        # intermittently answers with the names blanked, so a single read sees no Forest Test even
        # while it is in Play. Re-read before giving up -- `<runs-dir>/ftplay.py` has retried for
        # this reason since 2026-10-19.
        entries, candidates = [], []
        for attempt in range(10):
            entries = self.studio.studio_list()
            candidates = [e["id"] for e in entries if self.place in (e.get("name") or "")]
            if candidates:
                break
            if attempt < 9:
                time.sleep(3)
        if not candidates:
            raise SystemExit(
                "no Studio for place %s is connected (saw: %s)"
                % (self.place, ", ".join(repr(e.get("name")) for e in entries) or "none")
            )
        for sid in candidates:
            answer = self.studio.query("Client", "return tostring(game.PlaceId)", studio_id=sid) or ""
            if self.place in answer:
                return sid
        raise SystemExit(
            "the Forest Test is connected but has no Client DataModel -- it is not in Play. "
            "Start Play in place %s, walk onto the range mat, then run the bench again." % self.place
        )

    def client(self, src, **kw):
        return (self.studio.query("Client", oneline(src, **kw), studio_id=self.studio_id) or "").strip()

    def server(self, src, **kw):
        return (self.studio.query("Server", oneline(src, **kw), studio_id=self.studio_id) or "").strip()

    def attr(self, name):
        return self.client('local me = game:GetService("Players").LocalPlayer return tostring(me:GetAttribute("%s"))' % name)

    def install(self):
        return self.client(RESIDENT)

    def flags(self):
        """The place's flag rows, READ ONLY (rule K). Printed beside the table, never changed."""
        return self.server(
            'local ss = game:GetService("ServerStorage") local t = {} '
            "for k, v in pairs(ss:GetAttributes()) do if string.match(k, \"^DHFlag_\") then "
            't[#t + 1] = k .. "=" .. tostring(v) end end table.sort(t) '
            'return "placeId=" .. tostring(game.PlaceId) .. " " .. table.concat(t, " ")'
        )

    def pick(self, cell):
        """Choose the cell through the range's OWN remote -- the door the menu chips use.

        Returns (sent, board) so the caller prints the value picked and the board's own word on the
        SAME line (V298). A pick the server refused leaves the board reading the old trial, and the
        mismatch is the finding.
        """
        req = {"spot": 1, "pace": cell.pace, "weapon": cell.weapon, "species": cell.species}
        if cell.ammo:
            req["ammo"] = cell.ammo
        if cell.kind:
            req["kind"] = cell.kind
        lua = (
            'local RSt = game:GetService("ReplicatedStorage") '
            'local r = RSt:FindFirstChild("Range") r = r and r:FindFirstChild("Remotes") '
            'r = r and r:FindFirstChild("RangeRequest") '
            'if r == nil then return "no RangeRequest" end '
            "r:FireServer(%s) return \"sent\"" % _lua_table(req)
        )
        sent = self.client(lua)
        time.sleep(2.0)
        return sent, self.attr("DHBenchBoard")

    HELD = ('local me = game:GetService("Players").LocalPlayer local ch = me.Character '
            'local t = ch and ch:FindFirstChildOfClass("Tool") return tostring(t and t.Name)')

    def equip(self, cell):
        """Put the cell's gun in the CHARACTER through the hotbar's own digit key -- real input.

        THE KEY IS ONLY PRESSED WHILE THE WRONG GUN IS HELD: the hotbar digit TOGGLES, so
        pressing it for the gun already in hand puts it back in the backpack and the next cell
        fires nothing (measured here, 2026-10-28: the second cell read `held=nil`).
        """
        want = TOOL_NAME.get(cell.weapon, cell.weapon)
        held = ""
        for _ in range(3):
            held = self.client(self.HELD)
            if held == want:
                return "held=%s" % held
            key = HOTBAR.get(cell.weapon)
            if key is None:
                return "no hotbar key for %s (held=%s)" % (cell.weapon, held)
            self.studio.send_input(
                "keyboard", [{"action": "keyPress", "key_code": key}], studio_id=self.studio_id
            )
            time.sleep(1.0)
        return "held=%s WANTED %s" % (self.client(self.HELD), want)

    def set_mode(self, cell):
        self.client(
            'local me = game:GetService("Players").LocalPlayer '
            'me:SetAttribute("DHBenchMode", "%s") me:SetAttribute("DHBenchLead", %s) '
            'me:SetAttribute("DHBenchReset", (tonumber(me:GetAttribute("DHBenchReset")) or 0) + 1) '
            'return "mode"'
            % (cell.point, "true" if cell.lead else "false")
        )
        # The resident empties its row list on its next Heartbeat; reading before that would hand
        # back the previous cell's rows.
        time.sleep(0.5)

    def gate(self, minspd):
        return self.client(GATE, PX="%.1f" % self.viewport_px, MINSPD="%.2f" % minspd)

    def click(self):
        """ONE REAL LEFT CLICK through StudioMCP -- the Task-6 input route, so the whole client
        input chain runs. A `moveTo` first because StudioMCP refuses a button with no established
        position (`tools/studio_mcp.py`, the scenario validator's own rule)."""
        self.studio.send_input(
            "mouse",
            [
                {"action": "moveTo", "x": CLICK_XY[0], "y": CLICK_XY[1]},
                {"action": "mouseButtonClick", "mouse_button": "left", "x": CLICK_XY[0], "y": CLICK_XY[1]},
            ],
            studio_id=self.studio_id,
        )

    def bump(self):
        self.client(
            'local me = game:GetService("Players").LocalPlayer '
            'me:SetAttribute("DHBenchShot", (tonumber(me:GetAttribute("DHBenchShot")) or 0) + 1) return "x"'
        )

    def reload(self):
        self.studio.send_input("keyboard", [{"action": "keyPress", "key_code": "R"}], studio_id=self.studio_id)

    def hitlog(self):
        return self.server('return tostring(game:GetService("ServerStorage"):GetAttribute("DHLastHits"))')


# Where the click lands in the viewport. Under `MouseBehavior = LockCenter` the shot goes down the
# screen centre whatever this is, but StudioMCP refuses a mouse button with no established position
# (`tools/studio_mcp.py`, the scenario validator's own rule), so the pair is sent with every click.
CLICK_XY = (400, 300)

# The hotbar digits, as check305c drove them live (`held=` confirmed on the server each time).
HOTBAR = {"shotgun": "One", "rifle": "Two", "lever": "Three", "semiauto": "Four"}

# The Tool name each weapon id carries in the character, so `equip` tells "already held" from
# "the wrong gun" by reading the character rather than by guessing from the id.
TOOL_NAME = {"shotgun": "Shotgun", "rifle": "Rifle", "lever": "Lever", "semiauto": "SemiAuto"}

# A pace reads "at pace" above this fraction of its issued speed; `stand` is exempt.
PACE_FLOOR = {"stand": 0.0, "walk": 2.0, "trot": 7.0, "run": 15.0}


def _lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return '"%s"' % str(v).replace('"', '\\"')


def _lua_table(d):
    return "{ " + ", ".join("%s = %s" % (k, _lua_value(v)) for k, v in sorted(d.items())) + " }"


def run_cell(bench, cell, shots, log):
    """One cell -> its rows. Every refusal is reported, never retried silently."""
    log("")
    log("CELL %s" % cell.key)
    sent, board = bench.pick(cell)
    log("  picked %s -> RangeRequest %s | board: %s" % (cell.key, sent, board))
    log("  %s" % bench.equip(cell))
    bench.set_mode(cell)
    floor = PACE_FLOOR.get(cell.pace, 0.0)
    fired, refused_gate = 0, 0
    # THE RING LINE EACH SHOT WROTE (task 309a). `ServerStorage.DHLastHits` keeps only the last ten
    # lines, so a 30-shot cell must be read PER SHOT or nine tenths of it is gone. A miss writes
    # nothing, so the ring does not advance and that row keeps no ring columns -- and `seen` is
    # SEEDED FROM THE RING AS IT STANDS (round 1, finding 3), because the attribute persists across
    # cells and the first shot of a cell would otherwise inherit the previous cell's last line.
    rings = {}
    seen = ring_indices(bench.hitlog())
    while fired < shots:
        ready = ""
        for _ in range(60):
            ready = bench.gate(floor)
            if ready.startswith("READY"):
                break
            time.sleep(0.25)
        if not ready.startswith("READY"):
            refused_gate += 1
            log("  shot %d: gate never opened -- %s" % (fired + 1, ready))
            if refused_gate >= 3:
                log("  giving up on this cell after 3 closed gates")
                break
            continue
        bench.bump()
        bench.click()
        fired += 1
        time.sleep(1.5)
        tail = [ln.strip() for ln in (bench.hitlog() or "").splitlines() if ln.strip()]
        line = tail[-1] if tail else ""
        n = ring_credit(line, seen)
        if n is not None:
            rings[fired] = line
            seen.add(n)
        bench.reload()
        time.sleep(1.8)
    rows = parse_rows(bench.attr("DHBenchRows"))
    for r in rows:
        r.update(parse_trace(rings.get(r.get("i"))))
    log("  fired %d, rows %d, ring lines %d" % (fired, len(rows), len(rings)))
    for r in rows:
        log(
            "    #%s hit=%s answered=%s fired=%s frames=%s zone=%s spd=%s dist=%s along=%s up=%s "
            "across=%s aim=%s impact=%s card=(%s,%s) notice=%s src=%s | drawn=%s past=%s pres=%s "
            "pastat=%s pastgap=%s ring[zone=%s local=%s uv=%s id=%s]"
            % (r.get("i"), r.get("hit"), r.get("answered"), r.get("fired"), r.get("frames"),
               r.get("zone"), r.get("spd"), r.get("dist"), r.get("along"), r.get("up"),
               r.get("across"), r.get("aim"), r.get("impact"),
               r.get("cardu"), r.get("cardv"), r.get("notice"), r.get("src"),
               r.get("drawn"), r.get("past"), r.get("pres"), r.get("pastat"), r.get("pastgap"),
               r.get("ringzone"), r.get("ringlocal"), r.get("ringuv"), r.get("ringid"))
        )
    return rows


def cmd_run(args):
    cells = parse_cells(args.cells)
    cells = with_self_checks(cells)
    bench = Bench(place=args.place)
    lines = []

    def log(s):
        print(s, flush=True)
        lines.append(s)

    log("[aim_bench] studio=%s" % bench.studio_id)
    log("[aim_bench] %s" % bench.flags())
    log("[aim_bench] %s" % bench.install())
    results = []
    for cell in cells:
        results.append({"cell": cell, "rows": run_cell(bench, cell, args.shots, log)})
    log("")
    log("[aim_bench] last server hit trace (ServerStorage.DHLastHits):")
    for line in (bench.hitlog() or "").splitlines():
        log("    " + line)
    table, notes = summarise(results)
    header = [
        "AIM BENCH -- %s" % time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        "place %s, %d shots asked per cell" % (args.place, args.shots),
    ]
    text = render(table, notes, header)
    print("")
    print(text)
    lines.append("")
    lines.append(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        with open(os.path.splitext(args.out)[0] + ".json", "w", encoding="utf-8") as fh:
            json.dump(
                {"table": table, "notes": notes,
                 "cells": [{"cell": e["cell"].key, "rows": e["rows"]} for e in results]},
                fh, indent=1,
            )
        print("")
        print("written: %s" % args.out)
    return 0


def cmd_ray(args):
    """THE CLICK PROOF, in three parts, and the third is the one that settles it.

    1. NEGATIVE CONTROL. `DHClaimWhy` is cleared and nothing is clicked: it must stay nil.
    2. ONE REAL CLICK through `user_mouse_input`. `DHClaimWhy` comes back set -- and
       `src/client/Weapon/Input.luau` is the ONLY writer of that attribute in the whole repo
       (one grep hit), inside `Input.fire` itself. So the click ran the LIVE `Input.fire`, which
       that module's header calls the one firer of `FireRequest` in the client. The bench's input
       path IS a real click's path, because it is the same function a real click reaches.
    3. THE RAY, read on the frame `Input.fire` ran, from its own two expressions
       (`camera.CFrame.Position`, `camera.CFrame.LookVector.Unit`), printed beside the server's own
       impact. **THIS PART ASSERTS NOTHING AND MUST NOT** (round 1, finding 3): the server does not
       fly `req.direction` from `req.origin` -- `src/server/Weapon/init.luau` moves the origin onto
       the bore (`Ballistics.boreOrigin`) and elevates the line for the gun's zero
       (`Ballistics.launchDirection`, `Rifle.CONFIG.ZERO_STUDS`), so an impact a stud or two off the
       camera ray at 130 studs is the SHIPPED BALLISTIC, not a second input path. The offset is
       reported as a number to read, and the verdict rests on part 2 alone, which does bite.
    """
    bench = Bench(place=args.place)
    print("[aim_bench] studio=%s" % bench.studio_id)
    print("[aim_bench] %s" % bench.install())
    print("[aim_bench] %s" % bench.equip(parse_cell("rifle/run/chest")))
    time.sleep(2.5)
    print("[aim_bench] gate: %s" % bench.gate(0.0))

    clear = ('local me = game:GetService("Players").LocalPlayer '
             'me:SetAttribute("DHClaimWhy", nil) return tostring(me:GetAttribute("DHClaimWhy"))')
    print("")
    print("1. NEGATIVE CONTROL -- DHClaimWhy cleared, NO click sent:")
    print("   after clear:    %s" % bench.client(clear))
    time.sleep(2.0)
    idle = bench.attr("DHClaimWhy")
    print("   2 s later:      %s   (must be nil -- only Input.fire sets a VALUE here; the"
          " bench itself only ever writes nil)" % idle)

    print("")
    print("2. ONE REAL CLICK (StudioMCP user_mouse_input mouseButtonClick, left):")
    bench.bump()
    bench.click()
    time.sleep(2.5)
    why = bench.attr("DHClaimWhy")
    print("   DHClaimWhy:     %s" % why)
    print("   src/client/Weapon/Input.luau is the ONE writer of a VALUE to DHClaimWhy, inside")
    print("   Input.fire -- the client's ONE firer of FireRequest. So the click ran Input.fire.")

    rows = parse_rows(bench.attr("DHBenchRows"))
    ray = bench.attr("DHBenchRay")
    print("")
    print("3. THE RAY Input.fire SENT, its own two expressions read on the frame it RAN")
    print("   (the frame DHClaimWhy changed, %s Heartbeat(s) after the host asked):"
          % (rows[-1].get("frames") if rows else "?"))
    print("   origin|direction: %s" % ray)
    ok = idle in ("nil", "None", "") and why not in ("nil", "None", "")
    if not rows:
        print("   no ShotLanded row: nothing to cross-check the ray against.")
        return 0 if ok else 1
    row = rows[-1]
    print("   server impact:    %s   (hit=%s zone=%s)" % (row.get("impact"), row.get("hit"), row.get("zone")))
    try:
        o, d = ray.split("|")
        ox, oy, oz = [float(v) for v in o.split(",")]
        dx, dy, dz = [float(v) for v in d.split(",")]
        ix, iy, iz = [float(v) for v in str(row.get("impact")).split("|")]
        vx, vy, vz = ix - ox, iy - oy, iz - oz
        t = vx * dx + vy * dy + vz * dz
        px, py, pz = vx - t * dx, vy - t * dy, vz - t * dz
        off = math.sqrt(px * px + py * py + pz * pz)
        print("   the impact lies %.3f studs off that ray, over %.1f studs of flight (%.2f deg)"
              % (off, t, math.degrees(math.atan2(off, max(t, 1e-6)))))
        print("   NOT A CRITERION: the server flies from Ballistics.boreOrigin along")
        print("   Ballistics.launchDirection (elevated for the gun's zero), not from the camera")
        print("   along the camera ray, so a non-zero offset here is the shipped ballistic.")
    except (ValueError, AttributeError) as exc:
        print("   could not decompose: %s" % exc)
        return 1
    print("")
    print("VERDICT (parts 1 and 2 only): %s"
          % ("the bench's click ran the live Input.fire"
             if ok else "NOT PROVEN -- DHClaimWhy did not change as parts 1 and 2 require"))
    return 0 if ok else 1


def cmd_cells(_args):
    print("A CELL is  weapon[:ammo]/pace/point[+lead][~species[.kind]]")
    print("")
    print("  rifle/run/nose            shotgun:SLUG/run/nose         rifle/run/chest+lead")
    print("  rifle/trot/chestfront     rifle/run/nose~reddeer.stag   rifle/run/ahead")
    print("")
    print("points: " + ", ".join(POINTS))
    print("paces:  " + ", ".join(PACES))
    print("guns:   " + ", ".join(sorted(HOTBAR)))
    return 0


# ------------------------------------------------------------------------------------- selftest


def selftest():
    """Every pure rule, with no Studio and no network. CI runs this."""
    # --- the grammar
    c = parse_cell("rifle/run/nose")
    assert (c.weapon, c.ammo, c.pace, c.point, c.lead) == ("rifle", None, "run", "nose", False), c.key
    assert (c.species, c.kind) == ("boar", None), c.key
    assert c.key == "rifle/run/nose~boar", c.key
    c = parse_cell("shotgun:SLUG/trot/chestfront~reddeer.stag")
    assert (c.weapon, c.ammo, c.species, c.kind) == ("shotgun", "SLUG", "reddeer", "stag"), c.key
    assert c.key == "shotgun:SLUG/trot/chestfront~reddeer.stag", c.key
    c = parse_cell("rifle/run/chest+lead")
    assert c.lead and c.is_control and not c.is_known_bad
    assert parse_cell("rifle/run/ahead").is_known_bad
    for bad, why in [
        ("", "empty"), ("rifle", "no pace"), ("rifle/sprint/nose", "pace"),
        ("rifle/run/ear", "point"), ("rifle/run/ahead+lead", "known-bad takes no lead"),
        ("rifle//nose", "empty pace"),
    ]:
        try:
            parse_cell(bad)
        except CellError:
            pass
        else:
            raise AssertionError("parse_cell(%r) should have failed (%s)" % (bad, why))

    # --- the self-check cells are never optional (L-123)
    got = with_self_checks(parse_cells(["rifle/run/nose"]))
    assert len(got) == 3, [g.key for g in got]
    assert any(g.is_control for g in got) and any(g.is_known_bad for g in got)
    # ...and are not duplicated when the caller named them
    got = with_self_checks(parse_cells(["rifle/run/chest+lead", "rifle/run/ahead"]))
    assert len(got) == 2, [g.key for g in got]

    # --- Wilson, against published values
    low, high = wilson(9, 10)
    assert 0.55 < low < 0.60 and 0.98 < high <= 1.0, (low, high)
    low, high = wilson(0, 30)
    assert low < 1e-12 and 0.10 < high < 0.12, (low, high)
    assert wilson(0, 0) == (0.0, 0.0)
    # a 30-shot sample is tighter than a 10-shot one at the same rate -- the whole point of N=30
    assert (wilson(27, 30)[1] - wilson(27, 30)[0]) < (wilson(9, 10)[1] - wilson(9, 10)[0])

    # --- the row parser is total
    row = parse_row("i=3 hit=true zone=Chest spd=24.01 along=-1.250 up=nan cardu=nil src=nose")
    assert row["i"] == 3 and row["hit"] is True and row["zone"] == "Chest"
    assert row["spd"] == 24.01 and row["along"] == -1.25
    assert row["up"] is None and row["cardu"] is None
    assert parse_rows("i=1 hit=true\n\ngarbage\nnot a row\ni=2 hit=false") == [
        {"i": 1, "hit": True}, {"i": 2, "hit": False}
    ]
    assert parse_rows(None) == [] and parse_rows("") == []
    # the new per-shot columns parse like any other key, and `nil` stays None
    row = parse_row("i=4 drawn=1.00|2.00|3.00 past=1.00|2.00|4.00 pastat=102.5 pastgap=-0.730")
    assert row["drawn"] == "1.00|2.00|3.00" and row["pastat"] == 102.5 and row["pastgap"] == -0.73
    assert parse_row("i=5 past=nil pastgap=nan")["past"] is None

    # --- the ring parser (task 309a): a known-good line, and a known-bad one that must read NOTHING
    good = parse_trace(
        "#7 t=3.20s boar id=A1 zone=rear local=(0.05,0.44,1.29) uv=(0.733,0.381) dist=52.1 "
        "rifle/FMJ pellets=1 fatal=no"
    )
    assert good["ringzone"] == "rear" and good["ringlocal"] == "0.05|0.44|1.29", good
    assert good["ringuv"] == "0.733|0.381" and good["ringid"] == "A1", good
    assert abs(_ring_z({"ringlocal": good["ringlocal"]}) - 1.29) < 1e-9
    # L-141: the SAME parser pointed at something that is not a ring line must come back empty,
    # or every row would read as "the server answered" whatever the game did.
    for bad in (None, "", "no ring line here", "#3 t=1.0s boar id=A1 zone=rear"):
        empty = parse_trace(bad)
        assert empty == {"ringzone": None, "ringlocal": None, "ringuv": None, "ringid": None, "ringn": None}, bad
        assert _ring_z(empty) is None
    assert _ring_z({"ringlocal": "a|b|c"}) is None and _ring_z({}) is None
    assert good["ringn"] == 7, good

    # --- a ring line is credited ONCE, and never a line that was already there (finding 3)
    def ring(n):
        return "#%d t=1.00s boar id=A%d zone=rear local=(0.0,0.0,1.0) uv=(0.5,0.5) dist=50.0 r/S pellets=1 fatal=no" % (n, n)

    seen = ring_indices(ring(4) + chr(10) + ring(5))
    assert seen == {4, 5}, seen
    # the cell's first shot MISSES: the tail is still #5, which `seen` already holds -> no credit
    assert ring_credit(ring(5), seen) is None
    # ...and a genuinely new line is credited exactly once
    assert ring_credit(ring(6), seen) == 6
    seen.add(6)
    assert ring_credit(ring(6), seen) is None
    # a tail that is not a ring line at all credits nothing
    assert ring_credit("", seen) is None and ring_credit("garbage", seen) is None
    assert ring_indices(None) == set() and ring_indices("garbage") == set()

    # --- the instrument verdict (L-141): the two self-check cells must read DIFFERENTLY
    def entry(spec, hits, n, along=None):
        cell = parse_cell(spec)
        rows = [{"hit": i < hits, "zone": "Chest" if i < hits else None, "along": along} for i in range(n)]
        return {"cell": cell, "rows": rows}

    table, notes = summarise([
        entry("rifle/run/nose", 27, 30),
        entry("rifle/run/chest+lead", 28, 30),
        entry("rifle/run/ahead", 0, 30),
    ])
    assert notes == [], notes
    assert [r["role"] for r in table] == ["", "CONTROL", "KNOWN-BAD"], table
    assert table[0]["zones"] == {"Chest": 27}, table[0]

    # a known-bad that hits is the rig, not the game
    _, notes = summarise([entry("rifle/run/chest+lead", 28, 30), entry("rifle/run/ahead", 20, 30)])
    assert any("KNOWN-BAD" in n and "INSTRUMENT SUSPECT" in n for n in notes), notes
    # a control that misses is the rig, the pace or the build
    _, notes = summarise([entry("rifle/run/chest+lead", 5, 30), entry("rifle/run/ahead", 0, 30)])
    assert any("CONTROL" in n and "INSTRUMENT SUSPECT" in n for n in notes), notes
    # overlapping intervals: the rig cannot tell a good aim from clear air
    _, notes = summarise([entry("rifle/run/chest+lead", 16, 30), entry("rifle/run/ahead", 9, 30)])
    assert any("OVERLAPPING" in n for n in notes), notes
    # ...and with neither self-check cell the table says so rather than reading as clean
    _, notes = summarise([entry("rifle/run/nose", 27, 30)])
    assert any("NO CONTROL CELL" in n for n in notes) and any("NO KNOWN-BAD" in n for n in notes), notes
    # an empty cell is reported, not divided by zero
    table, notes = summarise([entry("rifle/run/chest+lead", 0, 0), entry("rifle/run/ahead", 0, 0)])
    assert table[0]["rate"] == 0.0 and table[0]["ci"] == (0.0, 0.0)
    assert any("CONTROL cell fired 0 shots" in n for n in notes), notes

    # --- a click the server never answered is NOT FIRED, never a miss (round 1, finding 4)
    def entry_raw(spec, rows):
        return {"cell": parse_cell(spec), "rows": rows}

    swallowed = entry_raw("semiauto/run/nose", [{"hit": False, "answered": False} for _ in range(30)])
    table, notes = summarise([swallowed, entry("rifle/run/chest+lead", 28, 30),
                              entry("rifle/run/ahead", 0, 30)])
    assert table[0]["n"] == 0 and table[0]["unanswered"] == 30, table[0]
    assert any("NOT A MEASUREMENT" in n and "semiauto" in n for n in notes), notes
    assert any("NO SHOT IN" in n for n in notes), notes
    # ...and a cell that mixes the two rates only the answered ones
    mixed = entry_raw("rifle/run/nose", [{"hit": True, "answered": True, "zone": "Chest"}] * 7
                      + [{"hit": False, "answered": False}] * 3)
    table, notes = summarise([mixed])
    assert table[0]["n"] == 7 and table[0]["hits"] == 7 and table[0]["unanswered"] == 3, table[0]
    assert render(table, notes, ["h"]).count("NOT FIRED") == 1
    # --- every control cell is checked, not only the last one named
    _, notes = summarise([entry("rifle/run/chest+lead", 28, 30), entry("rifle/trot/chest+lead", 2, 30),
                          entry("rifle/run/ahead", 0, 30)])
    assert any("MORE THAN ONE CONTROL CELL RAN" in n for n in notes), notes

    # --- the rendered table carries the numbers a reader checks the instrument by (L-123)
    table, notes = summarise([
        entry("rifle/run/nose", 27, 30, along=-0.4),
        entry("rifle/run/chest+lead", 28, 30, along=0.1),
        entry("rifle/run/ahead", 0, 30),
    ])
    text = render(table, notes, ["head"])
    assert "CONTROL" in text and "KNOWN-BAD" in text and "90%" in text and "-0.40" in text, text
    assert "Self-check: CONTROL and KNOWN-BAD both read as they must." in text

    # --- EVERY ROW CARRIES THE THREE INSTRUMENT COLUMNS, control included (L-143), and a cell whose
    # ring wrote nothing says `0/N` rather than reading as a clean zero.
    withring = entry_raw("rifle/run/chest", [
        {"hit": True, "answered": True, "zone": "rear", "along": -1.25, "pastgap": 0.62,
         "ringzone": "rear", "ringlocal": "0.05|0.44|1.29"},
        {"hit": True, "answered": True, "zone": "chest", "along": -0.20, "pastgap": 0.58,
         "ringzone": "body", "ringlocal": "0.02|0.50|0.71"},
    ])
    table, notes = summarise([withring, entry("rifle/run/chest+lead", 28, 30),
                              entry("rifle/run/ahead", 0, 30)])
    assert abs(table[0]["pastgap"] - 0.60) < 1e-9 and abs(table[0]["ringz"] - 1.00) < 1e-9, table[0]
    assert table[0]["rings"] == 2 and table[0]["ringdisagree"] == 1, table[0]
    assert table[1]["rings"] == 0 and table[1]["pastgap"] is None, table[1]
    text = render(table, notes, ["head"])
    assert "pastgap" in text and "ring-z" in text and "+0.60" in text and "+1.00" in text, text
    assert "2/2" in text and "0/30" in text, text
    assert "RING DISAGREES WITH THE MARKER on 1 row(s)" in text, text

    # --- `back` AND ITS DISAGREEMENT RULE (task 310). `back` is ring-z minus aim-z and `-along` is
    # the same quantity measured the other way, so a row where they differ by more than
    # OFFSET_DISAGREEMENT_STUDS is the finding the old table averaged away: `along=-0.78` beside a
    # ring at z=+1.42 with the aim at z=-0.41 is a strike 1.83 studs back, not 0.78.
    agree = {"hit": True, "answered": True, "zone": "body", "along": -0.90, "aimz": -0.41,
             "ringzone": "body", "ringlocal": "0.56|0.44|0.49"}
    disagree = {"hit": True, "answered": True, "zone": "rear", "along": -0.78, "aimz": -0.41,
                "ringzone": "rear", "ringlocal": "0.56|0.44|1.42"}
    assert abs(_back(agree) - 0.90) < 1e-9, _back(agree)
    assert abs(_back(disagree) - 1.83) < 1e-9, _back(disagree)
    assert offset_disagreement(agree) is False
    assert offset_disagreement(disagree) is True
    # A ROW CARRYING ONLY ONE OF THE TWO IS NOT A DISAGREEMENT -- an absent number never accuses.
    assert _back({"along": -0.78, "ringlocal": "0|0|1.42"}) is None
    assert _back({"along": -0.78, "aimz": -0.41}) is None
    assert offset_disagreement({"aimz": -0.41, "ringlocal": "0|0|1.42"}) is None
    assert offset_disagreement({"along": float("nan"), "aimz": -0.41, "ringlocal": "0|0|1.42"}) is None
    assert offset_disagreement({"along": -0.78, "aimz": float("nan"), "ringlocal": "0|0|1.42"}) is None
    # ...and the limit BITES: the same pair under a wider limit is no longer a disagreement.
    assert offset_disagreement(disagree, limit=2.0) is False
    withback = entry_raw("rifle/run/chest", [agree, disagree])
    table, notes = summarise([withback, entry("rifle/run/chest+lead", 28, 30),
                              entry("rifle/run/ahead", 0, 30)])
    assert abs(table[0]["back"] - 1.365) < 1e-9, table[0]
    assert table[0]["backs"] == 2 and table[0]["backdisagree"] == 1, table[0]
    assert table[1]["back"] is None and table[1]["backdisagree"] == 0, table[1]
    text = render(table, notes, ["head"])
    assert "back" in text and "+1.37" in text, text
    assert "OFFSET DISAGREEMENT on 1 of 2 row(s)" in text, text
    # the resident must actually write the column the rule reads, or the rule can never fire live
    assert "aimz=%s" in RESIDENT and "PointToObjectSpace(aim).Z" in RESIDENT
    livepair = parse_rows("i=1 hit=True answered=True zone=rear along=-0.780 up=0.0 across=0.5 "
                          "aimz=-0.410 aim=1.00|2.00|3.00 impact=1.00|2.00|3.00 cardu=nil cardv=nil "
                          "drawn=1.00|2.00|3.00 past=1.00|2.00|3.00 pres=1.00|2.00|3.00 "
                          "pastat=1.0 pastgap=0.0 notice=-")
    assert len(livepair) == 1 and abs(livepair[0]["aimz"] + 0.41) < 1e-9, livepair

    # --- the Luau goes down the wire as one line with its templates filled
    line = oneline(GATE, PX="12.0", MINSPD="15.00")
    assert "\n" not in line and "%PX%" not in line and "%MINSPD%" not in line
    assert "12.0" in line and "15.00" in line
    # THE STRIP MUST BITE, and this is the case that proves it (round 1, finding 5): `RESIDENT` does
    # carry `--` comment lines, and one surviving the join comments out the rest of the single line
    # the whole bench is installed from. The old assertion looked at `GATE` (which has no comment)
    # and only at the text before its first quote, so deleting the strip left it green.
    assert "\n--" in RESIDENT, "RESIDENT has no comment line, so this case proves nothing"
    resident = oneline(RESIDENT)
    assert "--" not in resident, "a comment survived the strip and would eat the whole line"
    assert "\n" not in resident and "DHTestLook" in resident and "DHBenchRows" in resident
    # THE CAMERA-WRITE GUARD, AND THE PROOF THAT IT BITES (round 2, finding 1). The guard is run
    # against the shipped text AND against four spellings of the write it forbids, so deleting the
    # `DHTestLook` steering and aiming the camera directly cannot leave this selftest green.
    assert camera_write_free(resident), "the bench must not write the camera"
    assert camera_write_free(oneline(GATE))
    for mutation in (
        "local cam = workspace.CurrentCamera cam.CFrame = CFrame.lookAt(origin, p)",
        "workspace.CurrentCamera.CFrame = cf",
        "cam.CFrame=CFrame.new(p)",
        "workspace.CurrentCamera.CFrame  =  cf",
    ):
        assert not camera_write_free(mutation), mutation
        assert not camera_write_free(resident + " " + mutation), mutation
    # ...and through `oneline`, which is the form `install` actually sends.
    for mutation in ("cam.CFrame = CFrame.lookAt(a, b)", "workspace.CurrentCamera.CFrame = cf"):
        assert not camera_write_free(oneline(RESIDENT + "\n" + mutation)), mutation

    # --- the Lua payload builder quotes what crosses the wire
    assert _lua_table({"pace": "run", "spot": 1}) == '{ pace = "run", spot = 1 }'
    assert _lua_value('a"b') == '"a\\"b"'

    # --- every gun the cell grammar accepts has a hotbar key, or a cell can never be equipped
    for gun in HOTBAR:
        assert parse_cell("%s/run/nose" % gun).weapon == gun
    # ...and every pace has a floor, or its gate would open at a standstill
    for pace in PACES:
        assert pace in PACE_FLOOR, pace
    assert PACE_FLOOR["run"] > PACE_FLOOR["trot"] > PACE_FLOOR["walk"] >= PACE_FLOOR["stand"]

    print("aim_bench selftest: OK")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(prog="aim_bench.py", description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd")
    sub.add_parser("selftest")
    sub.add_parser("cells")
    for name in ("run", "ray"):
        p = sub.add_parser(name)
        p.add_argument("--place", default=FOREST_TEST_PLACE)
        if name == "run":
            p.add_argument("cells", nargs="+")
            p.add_argument("--shots", type=int, default=30)
            p.add_argument("--out")
    args = ap.parse_args(argv)
    if args.cmd == "selftest":
        return selftest()
    if args.cmd == "cells":
        return cmd_cells(args)
    if args.cmd == "run":
        try:
            return cmd_run(args)
        except CellError as exc:
            print("bad cell: %s" % exc)
            return 1
    if args.cmd == "ray":
        return cmd_ray(args)
    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
