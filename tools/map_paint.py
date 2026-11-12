"""Render the painted M map: one PNG per drive cell plus one for the outer wood (task 354).

PATTERN: Leaflet's GridLayer tile layer (BSD-2-Clause) -- one image per tile, every tile placed by
the SAME projection the vector overlays use -- with the projection DERIVED from the game's own
geometry instead of fitted from calibration points, which is what the two DevForum answers do and
what this repo will not do (a second description of one thing).
Note: docs/research/2026-11-12-painted-map-images.md

PARENT: <runs-dir>/352/paint.py, the offline preview Karen approved on 2026-11-12 ("rest is ok").
What is new here is the per-cell SPLIT -- 352 rendered one combined canvas and nothing else -- and
reading the geometry out of the repo instead of out of a dumped JSON.

WHERE THE NUMBERS COME FROM: src/shared/Grid/init.luau (CONFIG, CELLS, PLANTED_CELLS) and
src/shared/Places/init.luau (CELL_PLANS' zone(...) rows, CELL_EDGE_STUDS), parsed here. Nothing is
transcribed: `check` prints every parsed value, and a field this parser cannot find is an error
rather than a default, so a renamed constant stops the render instead of painting a stale forest.

HOW THE EIGHT TILES TILE EXACTLY. One canvas is painted over the whole footprint plus the skirt, so
every noise field is continuous, and the tiles are CROPPED out of it. The crop boundaries are the
cell pitch lines (cell bounds grown by half the road clearance), rounded to whole canvas pixels ONCE
per boundary and shared by the two tiles that meet there -- so adjacent crops share an edge, with no
gap and no overlap. Each tile's world rect is then read BACK out of its rounded pixel box, which is
what makes MapUi's placement exact rather than nearly exact.

  python tools/map_paint.py check                 # parse the repo, print every number, render nothing
  python tools/map_paint.py render [--pps 0.70] [--out assets/ready/map]
  python tools/map_paint.py selftest              # offline, tiny canvas, no upload, no repo writes

Exit codes, the harness's shape: 0 done - 1 failed - 2 REFUSED before anything was written.
"""

import argparse
import io
import json
import math
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRID_LUAU = os.path.join(REPO, "src", "shared", "Grid", "init.luau")
PLACES_LUAU = os.path.join(REPO, "src", "shared", "Places", "init.luau")
SHOTGUN_LUAU = os.path.join(REPO, "src", "shared", "Shotgun", "init.luau")
OUT_DIR = os.path.join(REPO, "assets", "ready", "map")
TOOL_VERSION = "map-paint/1"

# THE REPO'S OWN TEXTURE CEILING (docs/research/2026-09-26-asset-pipeline.md). Roblox's platform
# limit for a Decal is "smaller than 8000x8000 pixels"; this one is ours and is far under it.
TEXTURE_MAX_PX = 1024
# HOW DEEP THE WOOD RUNS OUTSIDE THE EIGHT CELLS -- Places.skirtBands with no neighbour, whose cheap
# band ends at 420 studs. Task 350's picture stopped at the cells, so the world ended in grass on the
# paper and in wood on the ground.
SKIRT_DEEP_STUDS = 420.0
# ROOM FOR THE BEND on top of the skirt: bend.nsStuds is 60 and a crown is drawn a few studs wide.
BG_MARGIN_STUDS = 460.0
# THE REFERENCE SCALE EVERY PIXEL-SPACE CONSTANT BELOW WAS TUNED AT -- 352's own px/stud. A render at
# a different --pps scales each of them by pps/this, so the picture is the same picture at a
# different resolution rather than a different picture.
TUNED_PPS = 0.40


class Refused(Exception):
    pass


# ---------------------------------------------------------------- the repo, parsed

def _read(path):
    with io.open(path, encoding="utf-8") as handle:
        return handle.read()


def _scalar(text, name, what):
    """A `name = <number>,` line -- the first one, underscores allowed (327_001)."""
    pattern = r"^[ \t]*%s[ \t]*=[ \t]*(-?[\d_]+(?:\.\d+)?)[ \t]*,[ \t]*(?:--.*)?$" % re.escape(name)
    match = re.search(pattern, text, re.MULTILINE)
    if match is None:
        raise Refused("%s: no '%s = <number>' line. A renamed constant stops the render." % (what, name))
    return float(match.group(1).replace("_", ""))


GRID_SCALARS = ("originX", "originZ", "cellWidthStuds", "cellDepthStuds", "roadClearStuds",
                "roadPaintStuds", "rows", "columns", "mainStandCount", "mainSpacingStuds",
                "flankStandCount", "flankSpacingStuds", "flankMarginStuds", "seed")


def parse_grid(text=None):
    text = _read(GRID_LUAU) if text is None else text
    config = text.split("Grid.CONFIG", 1)[1].split("Grid.CELLS", 1)[0]
    out = dict((name, _scalar(config, name, "Grid.CONFIG")) for name in GRID_SCALARS)
    bend = config.split("bend", 1)[1]
    for name in ("ewStuds", "nsStuds", "harmonic"):
        out[name] = _scalar(bend, name, "Grid.CONFIG.bend")

    cells_text = text.split("Grid.CELLS", 1)[1].split("Grid.PLANTED_CELLS", 1)[0]
    cells = {}
    for block in re.split(r"\n\ttable\.freeze\(\{", cells_text):
        got = re.search(r'id = "([A-D][12])"', block)
        if got is None:
            continue
        cid = got.group(1)
        recipe = re.search(r'recipe = "(\w+)"', block)
        if recipe is None:
            raise Refused("Grid.CELLS.%s: no recipe" % cid)
        cells[cid] = dict(row=int(_scalar(block, "row", "Grid.CELLS." + cid)),
                          column=int(_scalar(block, "column", "Grid.CELLS." + cid)),
                          recipe=recipe.group(1),
                          lineMeanY=_scalar(block, "lineMeanY", "Grid.CELLS." + cid))
    want = int(out["rows"]) * int(out["columns"])
    if len(cells) != want:
        raise Refused("Grid.CELLS: parsed %d cells, expected %d" % (len(cells), want))

    planted = re.search(r"Grid\.PLANTED_CELLS = table\.freeze\(\{([^}]*)\}\)", text)
    if planted is None:
        raise Refused("Grid.PLANTED_CELLS: not found")
    out["planted"] = re.findall(r'"([A-D][12])"', planted.group(1))
    default = re.search(r'Grid\.DEFAULT_CELL = "([A-D][12])"', text)
    if default is None:
        raise Refused("Grid.DEFAULT_CELL: not found")
    out["defaultCell"] = default.group(1)
    out["cells"] = cells
    return out


# A ZONE ROW IS zone(x0, z0, x1, z1, spacing, "mix", "band"[, extra]) -- Places' own helper, whose
# only callers are the eight recipes. Read straight off the source, so a changed forest changes the
# picture with no snapshot of the data in between.
ZONE_RE = re.compile(
    r"\bzone\([ \t]*(-?[\d.]+)[ \t]*,[ \t]*(-?[\d.]+)[ \t]*,[ \t]*(-?[\d.]+)[ \t]*,"
    r"[ \t]*(-?[\d.]+)[ \t]*,[ \t]*(-?[\d.]+)[ \t]*,[ \t]*\"(\w+)\"[ \t]*,[ \t]*\"(\w+)\"")


def parse_places(text=None):
    text = _read(PLACES_LUAU) if text is None else text
    got = re.search(r"Places\.CELL_EDGE_STUDS = ([\d.]+)", text)
    if got is None:
        raise Refused("Places.CELL_EDGE_STUDS: not found")
    edge = float(got.group(1))
    plans = text.split("Places.CELL_PLANS", 1)
    if len(plans) < 2:
        raise Refused("Places.CELL_PLANS: not found")
    recipes, order, current = {}, [], None
    for line in plans[1].splitlines():
        head = re.match(r"^\t(\w+) = table\.freeze\(\{", line)
        if head is not None:
            current = head.group(1)
            recipes.setdefault(current, [])
            order.append(current)
            continue
        if current is None:
            continue
        for row in ZONE_RE.finditer(line):
            x0, z0, x1, z1, spacing, mix, band = row.groups()
            recipes[current].append(dict(x0=float(x0), z0=float(z0), x1=float(x1), z1=float(z1),
                                         spacing=float(spacing), mix=mix, band=band))
    recipes = dict((name, rows) for name, rows in recipes.items() if rows)
    if not recipes:
        raise Refused("Places.CELL_PLANS: no zone(...) rows parsed")
    return dict(edge=edge, recipes=recipes, order=[n for n in order if n in recipes])


def parse_slug_range(text=None):
    text = _read(SHOTGUN_LUAU) if text is None else text
    got = re.search(r"RANGE_STUDS = \{ Slug = ([\d.]+)", text)
    if got is None:
        raise Refused("Shotgun.CONFIG.RANGE_STUDS.Slug: not found")
    return float(got.group(1))


# ---------------------------------------------------------------- the geometry, mirroring Grid

class Geometry(object):
    """Grid's own arithmetic, in Python. Every method names the Luau function it mirrors, and
    tests/client/map_ui.spec.luau compares the points this produces against Grid's own."""

    def __init__(self, grid, places, slug_range):
        self.g = grid
        self.p = places
        self.slug = slug_range

    def pitch(self, axis):                                  # Grid.bendPitch
        g = self.g
        if axis == "x":
            return g["cellWidthStuds"] + g["roadClearStuds"]
        return g["cellDepthStuds"] + g["roadClearStuds"]

    def borigin(self, axis):                                # Grid.bendOrigin
        g = self.g
        return (g["originX"] if axis == "x" else g["originZ"]) + g["roadClearStuds"] / 2

    def bendZ(self, x):                                     # Grid.bendZ
        import numpy as np
        return self.g["ewStuds"] * np.sin(
            math.pi * self.g["harmonic"] * (x - self.borigin("x")) / self.pitch("x"))

    def bendX(self, z):                                     # Grid.bendX
        import numpy as np
        return self.g["nsStuds"] * np.sin(
            math.pi * self.g["harmonic"] * (z - self.borigin("z")) / self.pitch("z"))

    def toGrid(self, x, z):                                 # Grid.toGrid
        return x - self.bendX(z), z - self.bendZ(x)

    def toWorld(self, u, v):                                # Grid.toWorld -- the same fixed point
        x, z = u, v
        for _ in range(5):
            x = u + self.bendX(z)
            z = v + self.bendZ(x)
        return float(x), float(z)

    def footprint(self):                                    # Grid.footprint
        g = self.g
        return dict(minX=g["originX"],
                    maxX=g["originX"] + g["columns"] * g["cellWidthStuds"]
                    + (g["columns"] + 1) * g["roadClearStuds"],
                    minZ=g["originZ"],
                    maxZ=g["originZ"] + g["rows"] * g["cellDepthStuds"]
                    + (g["rows"] + 1) * g["roadClearStuds"])

    def rowsFromSouth(self, cid):
        return int(self.g["rows"] - self.g["cells"][cid]["row"])

    def boundsOf(self, cid):                                # Grid.boundsOf
        g = self.g
        c = g["cells"][cid]
        minX = g["originX"] + g["roadClearStuds"] \
            + (c["column"] - 1) * (g["cellWidthStuds"] + g["roadClearStuds"])
        minZ = g["originZ"] + g["roadClearStuds"] \
            + self.rowsFromSouth(cid) * (g["cellDepthStuds"] + g["roadClearStuds"])
        return dict(minX=minX, maxX=minX + g["cellWidthStuds"],
                    minZ=minZ, maxZ=minZ + g["cellDepthStuds"])

    def cellGround(self, cid):                              # the plantable rect, Places.zoneRect's base
        b = self.boundsOf(cid)
        e = self.p["edge"]
        return dict(minX=b["minX"] + e, maxX=b["maxX"] - e,
                    minZ=b["minZ"] + e, maxZ=b["maxZ"] - e)

    def roads(self):                                        # Grid.roads
        g = self.g
        box = self.footprint()
        half = g["roadClearStuds"] / 2
        out = []
        for row in range(int(g["rows"]) + 1):
            out.append(dict(id="EW%d" % (row + 1), axis="x",
                            at=g["originZ"] + half + row * (g["cellDepthStuds"] + g["roadClearStuds"]),
                            frm=box["minX"], to=box["maxX"]))
        for col in range(int(g["columns"]) + 1):
            out.append(dict(id="NS%d" % (col + 1), axis="z",
                            at=g["originX"] + half + col * (g["cellWidthStuds"] + g["roadClearStuds"]),
                            frm=box["minZ"], to=box["maxZ"]))
        return out

    def roadsOf(self, cid):                                 # Grid.roadsOf
        g = self.g
        c = g["cells"][cid]
        r = self.roads()
        ew = int(g["rows"]) + 1
        rfs = self.rowsFromSouth(cid)
        return dict(main=r[rfs], muster=r[rfs + 1],
                    west=r[ew + c["column"] - 1], east=r[ew + c["column"]])

    def roadPolyline(self, rd, n=160):                      # Grid.roadPolyline
        pts = []
        for i in range(n):
            along = rd["frm"] + (rd["to"] - rd["frm"]) * i / (n - 1)
            off = float(self.bendZ(along)) if rd["axis"] == "x" else float(self.bendX(along))
            ctr = rd["at"] + off
            pts.append((along, ctr) if rd["axis"] == "x" else (ctr, along))
        return pts

    def standCount(self):                                   # Grid.standCount
        return int(self.g["mainStandCount"] + 2 * self.g["flankStandCount"])

    def flankFirstStuds(self):                              # Grid.flankFirstStuds
        g = self.g
        dx0 = (g["cellWidthStuds"] / 2 + g["roadClearStuds"] / 2) \
            - ((g["mainStandCount"] - 1) / 2) * g["mainSpacingStuds"]
        slope_x = g["nsStuds"] * math.pi * g["harmonic"] / self.pitch("z")
        slope_z = g["ewStuds"] * math.pi * g["harmonic"] / self.pitch("x")
        f = math.ceil(math.sqrt(max(0.0, self.slug ** 2 - dx0 ** 2))) + g["flankMarginStuds"]
        for _ in range(3):
            dx = dx0 - slope_x * f
            f = math.ceil(math.sqrt(max(0.0, self.slug ** 2 - dx * dx)) + slope_z * dx0) \
                + g["flankMarginStuds"]
        return float(f)

    def standWorld(self, cid, index):                       # Grid.standWorld
        g = self.g
        b = self.boundsOf(cid)
        rd = self.roadsOf(cid)
        main_z = rd["main"]["at"]
        main = int(g["mainStandCount"])
        flank = int(g["flankStandCount"])
        if index <= main:
            middle = (main + 1) / 2
            u = (b["minX"] + b["maxX"]) / 2 + (index - middle) * g["mainSpacingStuds"]
            v = main_z
        else:
            west = index <= main + flank
            first = main + 1 if west else main + flank + 1
            v = main_z + self.flankFirstStuds() + (index - first) * g["flankSpacingStuds"]
            u = rd["west"]["at"] if west else rd["east"]["at"]
        return self.toWorld(u, v)

    # HOW A ZONE IS COLOURED -- the same five words and the same two rules MapUi.groundKindFor and
    # MapUi.groundDensityFor use, so the picture and the flag-off layer agree about the ground.
    def kindFor(self, mix, band, spacing):
        if spacing <= 0 or mix == "clearing":
            return "open"
        if band == "shrub":
            return "scrub"
        conifer = "spruce" in mix or "larch" in mix
        broad = "birch" in mix or "oak" in mix or "aspen" in mix
        if conifer and broad:
            return "mixed"
        return "conifer" if conifer else ("broadleaf" if broad else "mixed")

    def densityFor(self, spacing):
        if spacing <= 0:
            return 0.0
        return min(1.0, max(0.0, (60.0 - spacing) / (60.0 - 24.0)))

    def zoneRect(self, cid, zone):                          # Places.zoneRect
        g = self.cellGround(cid)
        width = g["maxX"] - g["minX"]
        depth = g["maxZ"] - g["minZ"]
        return (g["minX"] + zone["x0"] * width, g["minZ"] + zone["z0"] * depth,
                g["minX"] + zone["x1"] * width, g["minZ"] + zone["z1"] * depth)

    def zonesOf(self, cid):
        return self.p["recipes"].get(self.g["cells"][cid]["recipe"], [])


# ---------------------------------------------------------------- the tiling

def tile_plan(geo, pps):
    """The nine tiles, as whole-canvas-pixel boxes and the world rects those boxes mean.

    The canvas covers the footprint plus BG_MARGIN_STUDS on every side. A cell's tile is its bounds
    grown by half the road clearance, so the eight tiles tile the footprint's interior exactly: the
    boundary between two columns is ONE rounded pixel column, shared.
    """
    g = geo.g
    fp = geo.footprint()
    x0 = fp["minX"] - BG_MARGIN_STUDS
    x1 = fp["maxX"] + BG_MARGIN_STUDS
    z0 = fp["minZ"] - BG_MARGIN_STUDS
    z1 = fp["maxZ"] + BG_MARGIN_STUDS
    width = int(round((x1 - x0) * pps))
    height = int(round((z1 - z0) * pps))

    def cx(x):
        return int(round((x - x0) * pps))

    def cy(z):
        return int(round((z1 - z) * pps))

    half = g["roadClearStuds"] / 2
    # ONE rounded boundary per grid line, shared by the two tiles that meet on it.
    bx = [cx(fp["minX"] + half + i * (g["cellWidthStuds"] + g["roadClearStuds"]))
          for i in range(int(g["columns"]) + 1)]
    bz = [cy(fp["minZ"] + half + j * (g["cellDepthStuds"] + g["roadClearStuds"]))
          for j in range(int(g["rows"]) + 1)]

    def world_of_box(left, top, right, bottom):
        return dict(minX=x0 + left / pps, maxX=x0 + right / pps,
                    minZ=z1 - bottom / pps, maxZ=z1 - top / pps)

    tiles = []
    for cid in sorted(g["cells"]):
        col = g["cells"][cid]["column"] - 1
        rfs = geo.rowsFromSouth(cid)
        left, right = bx[col], bx[col + 1]
        bottom, top = bz[rfs], bz[rfs + 1]          # cy decreases as z grows
        tiles.append(dict(id=cid, kind="cell", box=(left, top, right, bottom),
                          rect=world_of_box(left, top, right, bottom)))
    tiles.append(dict(id="WOOD", kind="background", box=(0, 0, width, height),
                      rect=world_of_box(0, 0, width, height)))
    return dict(canvas=(width, height), x0=x0, x1=x1, z0=z0, z1=z1, pps=pps,
                boundsX=bx, boundsZ=bz, tiles=tiles)


def scaled_size(box, cap=TEXTURE_MAX_PX):
    """A crop's output size: its own pixels, shrunk so the long edge is at most `cap`."""
    left, top, right, bottom = box
    w, h = right - left, bottom - top
    if max(w, h) <= cap:
        return w, h
    scale = cap / float(max(w, h))
    return max(1, int(round(w * scale))), max(1, int(round(h * scale)))


# ---------------------------------------------------------------- the canvas, painted

def paint_canvas(geo, plan, verbose=True):
    """352's painting, at this plan's resolution. Every pixel-space constant is scaled by S."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter

    pps = plan["pps"]
    s = pps / TUNED_PPS
    width, height = plan["canvas"]
    x0, z1 = plan["x0"], plan["z1"]
    g = geo.g

    def hexc(text):
        return np.array([int(text[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])

    def noise(shape, scale, octaves=4, seed=0):
        rand = np.random.default_rng(seed)
        out = np.zeros(shape, dtype=np.float32)
        amp, total, step = 1.0, 0.0, float(scale) * s
        for _ in range(octaves):
            small_h = max(2, int(shape[0] / step))
            small_w = max(2, int(shape[1] / step))
            small = rand.random((small_h, small_w))
            img = np.asarray(Image.fromarray((small * 255).astype(np.uint8))
                             .resize((shape[1], shape[0]), Image.BICUBIC), dtype=np.float32) / 255.0
            out += img * amp
            total += amp
            amp *= 0.5
            step /= 2
        return out / total

    ys, xs = np.mgrid[0:height, 0:width]
    world_x = (x0 + (xs + 0.5) / pps).astype(np.float32)
    world_z = (z1 - (ys + 0.5) / pps).astype(np.float32)
    del ys, xs
    grid_u, grid_v = geo.toGrid(world_x, world_z)
    grid_u = grid_u.astype(np.float32)
    grid_v = grid_v.astype(np.float32)

    rng = np.random.default_rng(int(g["seed"]))

    # DOMAIN WARP (Inigo Quilez, "Domain warping"; Red Blob Games, "Making maps with noise
    # functions" -- the pattern Places' own header cites): the zone rect is read at a point pushed
    # off by two low-frequency noise fields, so a straight boundary comes out organic.
    feather = 95.0
    warp = 150.0
    warp_u = ((noise((height, width), 120, 3, 21) - 0.5) * 2 * warp
              + (noise((height, width), 40, 3, 22) - 0.5) * 2 * (warp * 0.35))
    warp_v = ((noise((height, width), 120, 3, 23) - 0.5) * 2 * warp
              + (noise((height, width), 40, 3, 24) - 0.5) * 2 * (warp * 0.35))
    grid_u += warp_u.astype(np.float32)
    grid_v += warp_v.astype(np.float32)
    del warp_u, warp_v

    def soft(arr, lo, hi, feath):
        return np.clip((arr - lo) / feath, 0, 1) * np.clip((hi - arr) / feath, 0, 1)

    kinds = ("open", "scrub", "broadleaf", "conifer", "mixed")
    weight = dict((k, np.zeros((height, width), dtype=np.float32)) for k in kinds)
    dens = np.zeros((height, width), dtype=np.float32)
    wtot = np.zeros((height, width), dtype=np.float32)
    cell_feather = 26.0         # the wood runs to its own verge; only ZONE edges take the big one
    for cid in g["planted"]:
        ground = geo.cellGround(cid)
        in_cell = (soft(grid_u, ground["minX"] - 14, ground["maxX"] + 14, cell_feather)
                   * soft(grid_v, ground["minZ"] - 14, ground["maxZ"] + 14, cell_feather))
        if in_cell.max() <= 0:
            continue
        for zone in geo.zonesOf(cid):
            a0, b0, a1, b1 = geo.zoneRect(cid, zone)
            mask = (soft(grid_u, a0 - feather / 2, a1 + feather / 2, feather)
                    * soft(grid_v, b0 - feather / 2, b1 + feather / 2, feather) * in_cell)
            if mask.max() <= 0:
                continue
            weight[geo.kindFor(zone["mix"], zone["band"], zone["spacing"])] += mask
            dens += mask * geo.densityFor(zone["spacing"])
            wtot += mask

    # THE OUTER SKIRT (task 352). Places.skirtBands with no neighbour plants out to 420 studs, so
    # each boundary cell's rim is drawn in its own front mix at the cheap band's 34-stud pitch.
    fp = geo.footprint()
    for cid in g["planted"]:
        ground = geo.cellGround(cid)
        zones = geo.zonesOf(cid)
        if not zones:
            continue
        kind = geo.kindFor(zones[0]["mix"], zones[0]["band"], 34.0)
        for axis, lo, hi in (("x", fp["minX"], fp["maxX"]), ("z", fp["minZ"], fp["maxZ"])):
            for side, edge in ((-1, lo), (1, hi)):
                if axis == "x":
                    if side < 0 and ground["minX"] > edge + 60:
                        continue
                    if side > 0 and ground["maxX"] < edge - 60:
                        continue
                    a0, a1 = (edge - SKIRT_DEEP_STUDS, edge) if side < 0 else (edge, edge + SKIRT_DEEP_STUDS)
                    b0, b1 = ground["minZ"], ground["maxZ"]
                else:
                    if side < 0 and ground["minZ"] > edge + 60:
                        continue
                    if side > 0 and ground["maxZ"] < edge - 60:
                        continue
                    b0, b1 = (edge - SKIRT_DEEP_STUDS, edge) if side < 0 else (edge, edge + SKIRT_DEEP_STUDS)
                    a0, a1 = ground["minX"], ground["maxX"]
                mask = (soft(grid_u, a0 - feather / 2, a1 + feather / 2, feather)
                        * soft(grid_v, b0 - feather / 2, b1 + feather / 2, feather))
                if mask.max() <= 0:
                    continue
                weight[kind] += mask * 0.9
                dens += mask * geo.densityFor(34.0) * 0.9
                wtot += mask * 0.9

    safe = np.maximum(wtot, 1e-6)
    for k in kinds:
        weight[k] /= safe
    dens /= safe
    forest = np.clip(wtot, 0, 1)
    del safe, wtot, grid_u, grid_v

    grass = hexc("8a8656")
    grass2 = hexc("a69c62")
    palette = dict(conifer=hexc("223a27"), broadleaf=hexc("4a6730"), mixed=hexc("334a2b"),
                   scrub=hexc("6f7342"), open=grass)
    gn = noise((height, width), 220, 5, 11)[..., None]
    base = (grass[None, None, :] * (1 - gn * 0.55) + grass2[None, None, :] * (gn * 0.55))
    floor = np.zeros((height, width, 3), dtype=np.float32)
    for k in kinds:
        floor += weight[k][..., None] * palette[k][None, None, :].astype(np.float32)
    img = (base * (1 - forest[..., None]) + (base * 0.35 + floor * 0.65) * forest[..., None]
           ).astype(np.float32)
    del base, floor, gn

    # RELIEF SHADING, off the surveyed lineMeanY of each cell.
    hgt = np.zeros((height, width), dtype=np.float32)
    hw = np.zeros((height, width), dtype=np.float32)
    for cid, cell in g["cells"].items():
        b = geo.boundsOf(cid)
        d2 = (((world_x - (b["minX"] + b["maxX"]) / 2) / 900.0) ** 2
              + ((world_z - (b["minZ"] + b["maxZ"]) / 2) / 900.0) ** 2)
        w = np.exp(-d2).astype(np.float32)
        hgt += w * cell["lineMeanY"]
        hw += w
    hgt /= np.maximum(hw, 1e-6)
    hgt = hgt / max(1e-6, float(hgt.max() - hgt.min())) * 40.0 + noise((height, width), 140, 5, 7) * 26.0
    grad_y, grad_x = np.gradient(hgt)
    # THE GRADIENT IS PER PIXEL, so its magnitude scales with the resolution: /s keeps the same hill.
    shade = np.clip(1.0 + (-grad_x * 0.9 + grad_y * 0.9) * 0.5 / s, 0.72, 1.28)[..., None]
    img *= shade.astype(np.float32)
    del hgt, hw, grad_x, grad_y, shade

    def to_px(x, z):
        return (x - x0) * pps, (z1 - z) * pps

    road_mask = Image.new("L", (width, height), 0)
    paint_mask = Image.new("L", (width, height), 0)
    draw_road = ImageDraw.Draw(road_mask)
    draw_paint = ImageDraw.Draw(paint_mask)
    for rd in geo.roads():
        pts = [to_px(x, z) for x, z in geo.roadPolyline(rd)]
        draw_road.line(pts, fill=255, width=max(1, int(g["roadClearStuds"] * pps)), joint="curve")
        draw_paint.line(pts, fill=255, width=max(1, int(g["roadPaintStuds"] * pps)), joint="curve")
    verge = np.asarray(road_mask.filter(ImageFilter.GaussianBlur(3.0 * s)), dtype=np.float32) / 255
    carriage = np.asarray(paint_mask.filter(ImageFilter.GaussianBlur(2.2 * s)), dtype=np.float32) / 255
    rn = noise((height, width), 14, 3, 5)[..., None]
    verge_c = hexc("968f58")
    dirt_c = hexc("ab9a6d")
    img = img * (1 - verge[..., None] * 0.95) + (verge_c * (0.82 + rn * 0.34)) * (verge[..., None] * 0.95)
    img = img * (1 - carriage[..., None]) + (dirt_c * (0.86 + rn * 0.28)) * carriage[..., None]
    img = img.astype(np.float32)
    del road_mask, paint_mask, rn, carriage

    # THE CANOPY STIPPLE -- the painterly part. The crown grid is in STUDS, so the same trees are
    # drawn at any --pps; only their pixel radius scales.
    crown_pitch = 15.0
    nx = int((plan["x1"] - x0) / crown_pitch)
    nz = int((z1 - plan["z0"]) / crown_pitch)
    cxg, czg = np.meshgrid(x0 + (np.arange(nx) + 0.5) * crown_pitch,
                           plan["z0"] + (np.arange(nz) + 0.5) * crown_pitch)
    cxg = cxg + rng.normal(0, crown_pitch * 0.42, cxg.shape)
    czg = czg + rng.normal(0, crown_pitch * 0.42, czg.shape)
    ix = np.clip(((cxg - x0) * pps).astype(int), 0, width - 1)
    iz = np.clip(((z1 - czg) * pps).astype(int), 0, height - 1)
    dloc = dens[iz, ix]
    floc = forest[iz, ix]
    on_road = verge[iz, ix]
    # GLADES AND THICKETS: a slow field over the crown probability, so density varies inside a zone
    # the way a real wood does. Without it a zone is a flat carpet with a straight border.
    clump = noise((height, width), 70, 4, 31)[iz, ix]
    prob = (np.clip(0.30 + 0.70 * dloc, 0, 1) * floc * (on_road < 0.42)
            * np.clip(0.58 + 0.95 * clump, 0, 1.0))
    keep = rng.random(prob.shape) < prob
    sel = np.stack([ix[keep], iz[keep]], 1)
    wc = weight["conifer"][sel[:, 1], sel[:, 0]]
    wb = weight["broadleaf"][sel[:, 1], sel[:, 0]]
    wm = weight["mixed"][sel[:, 1], sel[:, 0]]
    roll = rng.random(sel.shape[0])
    pc = wc + wm * 0.5
    pb = pc + wb + wm * 0.5
    species = np.where(roll < pc, 0, np.where(roll < pb, 1, 2))
    conifer_c = [hexc("1c2e20"), hexc("2a4029")]
    broad_c = [hexc("465c2b"), hexc("687034")]
    pale_c = [hexc("8b9450"), hexc("a39a5d")]
    autumn_c = [hexc("8a6f32"), hexc("a8853f")]   # Style.LOOK.AMBER_BAR is the warm end of this pair
    radii = (np.clip(2.4 + 3.0 * dloc[keep], 1.8, 5.8) * s
             * rng.lognormal(0.0, 0.34, sel.shape[0])).astype(np.float32)
    cap = int(math.ceil(9 * s))
    kern = {}

    def kernel(radius):
        radius = max(1, min(int(round(radius)), cap))
        if radius in kern:
            return kern[radius]
        yy, xx = np.mgrid[-radius:radius + 1, -radius:radius + 1]
        dd = np.sqrt(xx * xx + yy * yy) / radius
        kern[radius] = np.clip(1.0 - dd ** 1.7, 0, 1)
        return kern[radius]

    shadow = np.array([0.06, 0.09, 0.06], dtype=np.float32)
    drop = max(1, int(round(2 * s)))
    layer = img
    if verbose:
        print("[map-paint] crowns: %d" % sel.shape[0])
    for idx in np.argsort(sel[:, 1]):
        x, y = int(sel[idx, 0]), int(sel[idx, 1])
        k = kernel(radii[idx])
        rr = k.shape[0] // 2
        xa, xb = max(0, x - rr), min(width, x + rr + 1)
        ya, yb = max(0, y - rr), min(height, y + rr + 1)
        if xb <= xa or yb <= ya:
            continue
        kk = k[ya - (y - rr):k.shape[0] - ((y + rr + 1) - yb),
               xa - (x - rr):k.shape[1] - ((x + rr + 1) - xb)][..., None]
        kind = species[idx]
        t = float(rng.random())
        if kind == 0:
            col = conifer_c[0] * (1 - t) + conifer_c[1] * t
        elif kind == 1:
            col = broad_c[0] * (1 - t) + broad_c[1] * t
            if t > 0.80:                       # ~20 % turned leaf, the autumn Karen keeps asking for
                col = autumn_c[0] * (1 - t) + autumn_c[1] * t
        else:
            col = pale_c[0] * (1 - t) + pale_c[1] * t
        col = (col * (0.86 + 0.28 * float(rng.random()))).astype(np.float32)
        sy0 = min(height, ya + drop)
        sx0 = min(width, xa + drop)
        kh = min(min(height, yb + drop) - sy0, kk.shape[0])
        kw = min(min(width, xb + drop) - sx0, kk.shape[1])
        if kh > 0 and kw > 0:
            alpha = (kk[:kh, :kw] * 0.45).astype(np.float32)
            layer[sy0:sy0 + kh, sx0:sx0 + kw] = (layer[sy0:sy0 + kh, sx0:sx0 + kw] * (1 - alpha)
                                                 + shadow * alpha)
        alpha = (kk * 0.92).astype(np.float32)
        layer[ya:yb, xa:xb] = layer[ya:yb, xa:xb] * (1 - alpha) + col.astype(np.float32) * alpha
    img = layer

    # PAINT-OVER: soft focus, grain, vignette, then a contrast and saturation lift.
    img = np.clip(img, 0, 1)
    pic = Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6 * s))
    arr = np.asarray(pic, dtype=np.float32) / 255
    arr = np.clip(arr + (noise((height, width), 3, 2, 99)[..., None] - 0.5) * 0.055, 0, 1)
    vy, vx = np.mgrid[0:height, 0:width]
    vig = 1 - 0.22 * (((vx / width - 0.5) ** 2 + (vy / height - 0.5) ** 2) * 2.6)
    arr = np.clip(arr * vig[..., None].astype(np.float32), 0, 1)
    mean = arr.mean(axis=2, keepdims=True)
    arr = np.clip(mean + (arr - mean) * 1.18, 0, 1)
    arr = np.clip((arr - 0.5) * 1.12 + 0.48, 0, 1)
    return Image.fromarray((arr * 255).astype(np.uint8))


# ---------------------------------------------------------------- the landmarks, for the proof

def landmarks(geo, plan):
    """Every point the alignment table is measured at, as (world point, tile, pixel in that tile).

    The pixel is this script's OWN arithmetic -- the canvas px() mapping minus the crop's origin --
    so map_ui.spec compares two independent expressions rather than one expression with itself.
    """
    pps, x0, z1 = plan["pps"], plan["x0"], plan["z1"]
    by_id = dict((t["id"], t) for t in plan["tiles"])

    def found(name, x, z, tile, cx, cy):
        """The pixel in the SAVED image, which is the crop scaled to its output size -- so a spec
        can compare against the file it actually draws and not against an intermediate."""
        left, top, right, bottom = tile["box"]
        out_w, out_h = scaled_size(tile["box"])
        return dict(name=name, worldX=x, worldZ=z, tile=tile["id"],
                    pxX=(cx - left) * out_w / float(right - left),
                    pxY=(cy - top) * out_h / float(bottom - top),
                    outW=out_w, outH=out_h)

    def place(name, x, z):
        cx = (x - x0) * pps
        cy = (z1 - z) * pps
        for tile in plan["tiles"]:
            if tile["kind"] != "cell":
                continue
            left, top, right, bottom = tile["box"]
            if left <= cx <= right and top <= cy <= bottom:
                return found(name, x, z, tile, cx, cy)
        return found(name, x, z, by_id["WOOD"], cx, cy)

    out = []
    active = geo.g["defaultCell"]
    for i in range(1, geo.standCount() + 1):
        x, z = geo.standWorld(active, i)
        out.append(place("stand%s%d" % (active, i), x, z))
    for cid in sorted(geo.g["cells"]):
        b = geo.boundsOf(cid)
        # THE CELL'S FOUR CORNERS, pushed through the bend exactly as MapUi's cell box is NOT -- the
        # box is axis-aligned on the UNBENT bounds, so the corners are the bounds themselves.
        for cx, cz, corner in ((b["minX"], b["minZ"], "SW"), (b["maxX"], b["minZ"], "SE"),
                               (b["maxX"], b["maxZ"], "NE"), (b["minX"], b["maxZ"], "NW")):
            out.append(place("corner%s%s" % (cid, corner), cx, cz))
    for rd in geo.roadsOf(active).values():
        pts = geo.roadPolyline(rd, 9)
        for i, (x, z) in enumerate(pts):
            out.append(place("road%s_%d" % (rd["id"], i + 1), x, z))
    return out


# ---------------------------------------------------------------- the Luau manifest

def manifest_luau(plan, geo, ids, sizes):
    lines = []
    add = lines.append
    add("--!strict")
    add("-- THE PAINTED MAP'S TILES: one picture per drive cell plus one for the outer wood.")
    add("--")
    add("-- GENERATED by `python tools/map_paint.py render` -- EDIT THAT, NOT THIS. Each rect is the")
    add("-- world rectangle its picture covers, read back out of the crop's whole-pixel box, so")
    add("-- `MapUi.rawOffsetPx(rect.minX, rect.maxZ)` and `(rect.maxX, rect.minZ)` are the image's")
    add("-- exact corners -- the Leaflet tile-layer pattern with the projection derived, not fitted.")
    add("-- Note: docs/research/2026-11-12-painted-map-images.md")
    add("--")
    add("-- `assetId` 0 means NOT UPLOADED YET, and `MapUi` draws no tile for it. Every non-zero id")
    add("-- has a row in `assets/uploads.json` carrying its sha256, its moderation state and Karen's")
    add("-- OK. A Decal cannot be updated through the Assets API, so a re-render is a NEW id.")
    add("")
    add("export type Tile = {")
    add("\tid: string,")
    add("\tkind: string, -- \"cell\" or \"background\"")
    add("\tassetId: number,")
    add("\tpixels: { width: number, height: number },")
    add("\trect: { minX: number, maxX: number, minZ: number, maxZ: number },")
    add("}")
    add("")
    add("local PaintedMap = {}")
    add("")
    add("PaintedMap.VERSION = \"%s\"" % TOOL_VERSION)
    add("PaintedMap.PX_PER_STUD = %s" % fmt(plan["pps"]))
    add("")
    add("PaintedMap.TILES = table.freeze({")
    for tile in plan["tiles"]:
        rect = tile["rect"]
        out_w, out_h = sizes[tile["id"]]
        add("\ttable.freeze({")
        add("\t\tid = \"%s\"," % tile["id"])
        add("\t\tkind = \"%s\"," % tile["kind"])
        add("\t\tassetId = %d," % ids.get(tile["id"], 0))
        add("\t\tpixels = table.freeze({ width = %d, height = %d })," % (out_w, out_h))
        add("\t\trect = table.freeze({")
        for key in ("minX", "maxX", "minZ", "maxZ"):
            add("\t\t\t%s = %s," % (key, fmt(rect[key])))
        add("\t\t}),")
        add("\t}),")
    add("}) :: { Tile }")
    add("")
    add("-- THE TILE AN `id` NAMES, or nil. A linear scan over nine rows, called once per open.")
    add("function PaintedMap.tile(id: string): Tile?")
    add("\tfor _, tile in ipairs(PaintedMap.TILES) do")
    add("\t\tif tile.id == id then")
    add("\t\t\treturn tile")
    add("\t\tend")
    add("\tend")
    add("\treturn nil")
    add("end")
    add("")
    add("return PaintedMap")
    return "\n".join(lines) + "\n"


def fmt(value):
    """A number as Luau source: an integer when it is one, else SHORTEST ROUND-TRIP.

    Not `%.10g`: a tile rect truncated to ten digits is a rect that is no longer exactly the one its
    pixel box means, and this file's whole claim is that it is exact. Python's repr and Luau's reader
    are both IEEE-754 doubles, so repr round-trips.
    """
    if abs(value - round(value)) < 1e-9:
        return "%d" % int(round(value))
    return repr(float(value))


# ---------------------------------------------------------------- commands

def cmd_check(args):
    grid = parse_grid()
    places = parse_places()
    slug = parse_slug_range()
    geo = Geometry(grid, places, slug)
    print("[map-paint] %s  check" % TOOL_VERSION)
    for name in GRID_SCALARS + ("ewStuds", "nsStuds", "harmonic"):
        print("  Grid.CONFIG.%-20s %s" % (name, fmt(grid[name])))
    print("  Places.CELL_EDGE_STUDS    %s" % fmt(places["edge"]))
    print("  Shotgun RANGE_STUDS.Slug  %s" % fmt(slug))
    print("  flankFirstStuds           %s" % fmt(geo.flankFirstStuds()))
    print("  standCount                %d" % geo.standCount())
    print("  DEFAULT_CELL              %s" % grid["defaultCell"])
    print("  PLANTED_CELLS             %s" % ",".join(grid["planted"]))
    print("  recipes (%d)              %s" % (len(places["recipes"]), ",".join(places["order"])))
    total = sum(len(rows) for rows in places["recipes"].values())
    print("  zone rows                 %d" % total)
    for cid in sorted(grid["cells"]):
        cell = grid["cells"][cid]
        rows = places["recipes"].get(cell["recipe"], [])
        print("    %s row=%d col=%d recipe=%-20s zones=%2d lineMeanY=%s"
              % (cid, cell["row"], cell["column"], cell["recipe"], len(rows), fmt(cell["lineMeanY"])))
    plan = tile_plan(geo, args.pps)
    print("  canvas                    %d x %d px at %s px/stud"
          % (plan["canvas"][0], plan["canvas"][1], fmt(plan["pps"])))
    for tile in plan["tiles"]:
        left, top, right, bottom = tile["box"]
        out_w, out_h = scaled_size(tile["box"])
        rect = tile["rect"]
        print("    %-4s %-10s crop %4d,%4d %4dx%4d -> %4dx%4d  world x %s..%s z %s..%s"
              % (tile["id"], tile["kind"], left, top, right - left, bottom - top, out_w, out_h,
                 fmt(rect["minX"]), fmt(rect["maxX"]), fmt(rect["minZ"]), fmt(rect["maxZ"])))
    gaps = check_tiling(plan)
    print("  tiling                    %s" % ("exact, no gap and no overlap" if not gaps
                                              else "BROKEN: " + "; ".join(gaps)))
    return 1 if gaps else 0


def check_tiling(plan):
    """The eight cell crops must share every interior boundary, with no gap and no overlap."""
    problems = []
    cells = [t for t in plan["tiles"] if t["kind"] == "cell"]
    lefts = sorted(set(t["box"][0] for t in cells))
    rights = sorted(set(t["box"][2] for t in cells))
    if lefts[1:] != rights[:-1]:
        problems.append("column boundaries %s do not meet %s" % (lefts[1:], rights[:-1]))
    tops = sorted(set(t["box"][1] for t in cells))
    bottoms = sorted(set(t["box"][3] for t in cells))
    if tops[1:] != bottoms[:-1]:
        problems.append("row boundaries %s do not meet %s" % (tops[1:], bottoms[:-1]))
    for tile in cells:
        left, top, right, bottom = tile["box"]
        if right <= left or bottom <= top:
            problems.append("%s has an empty crop" % tile["id"])
    return problems


def cmd_render(args):
    grid = parse_grid()
    places = parse_places()
    geo = Geometry(grid, places, parse_slug_range())
    plan = tile_plan(geo, args.pps)
    gaps = check_tiling(plan)
    if gaps:
        raise Refused("the tiling is broken: " + "; ".join(gaps))
    out_dir = args.out or OUT_DIR
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    print("[map-paint] %s  canvas %d x %d px at %s px/stud"
          % (TOOL_VERSION, plan["canvas"][0], plan["canvas"][1], fmt(plan["pps"])))
    from PIL import Image
    canvas = paint_canvas(geo, plan)
    sizes, written = {}, []
    for tile in plan["tiles"]:
        box = tile["box"]
        out_w, out_h = scaled_size(box)
        sizes[tile["id"]] = (out_w, out_h)
        crop = canvas.crop(box)
        if (out_w, out_h) != (box[2] - box[0], box[3] - box[1]):
            crop = crop.resize((out_w, out_h), Image.LANCZOS)
        path = os.path.join(out_dir, "%s.png" % tile["id"].lower())
        crop.save(path, optimize=True)
        written.append(path)
        print("  %-4s %4d x %4d px  %7.1f KB  %s"
              % (tile["id"], out_w, out_h, os.path.getsize(path) / 1024.0, os.path.basename(path)))
    marks = landmarks(geo, plan)
    # THE PROOF TABLE SHIPS WITH THE PLACE, as a Rojo JSON module (CLAUDE.md "File types": a .json in
    # a Rojo path becomes a ModuleScript returning the decoded table). tests/client/map_ui.spec.luau
    # reads it and compares THIS script's pixel for each world point against MapUi.paintedRectPx's --
    # two independent instruments, which is the only kind of alignment claim worth making.
    marks_path = os.path.join(REPO, "src", "shared", "Map", "PaintedLandmarks.json")
    with io.open(marks_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(dict(tool=TOOL_VERSION, pxPerStud=plan["pps"], landmarks=marks),
                  handle, indent=1, sort_keys=True)
        handle.write("\n")
    print("  src/shared/Map/PaintedLandmarks.json  %d points" % len(marks))
    ids = read_ids(args.ids)
    text = manifest_luau(plan, geo, ids, sizes)
    with io.open(os.path.join(REPO, "src", "shared", "Map", "PaintedMap.luau"), "w",
                 encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("  src/shared/Map/PaintedMap.luau  %d tiles, %d with an asset id"
          % (len(plan["tiles"]), sum(1 for v in ids.values() if v)))
    return 0


def read_ids(path):
    """tile id -> Roblox asset id, from a JSON file. Absent is all zeros (nothing uploaded yet)."""
    if not path:
        path = os.path.join(OUT_DIR, "asset-ids.json")
    if not os.path.isfile(path):
        return {}
    with io.open(path, encoding="utf-8") as handle:
        raw = json.load(handle)
    return dict((str(k), int(v)) for k, v in raw.items())


# ---------------------------------------------------------------- selftest

def cmd_selftest(_args):
    fails, ran = [], []

    def ok(what, condition, detail=""):
        ran.append(what)
        print("  %s %s%s" % ("ok  " if condition else "FAIL", what, "" if condition else "  -- " + detail))
        if not condition:
            fails.append(what)

    print("[map-paint] selftest")
    grid = parse_grid()
    places = parse_places()
    slug = parse_slug_range()
    geo = Geometry(grid, places, slug)

    ok("the repo's Grid.CONFIG parses to 17 numbers",
       all(isinstance(grid[n], float) for n in GRID_SCALARS + ("ewStuds", "nsStuds", "harmonic")))
    ok("every cell has a recipe with zones",
       all(places["recipes"].get(c["recipe"]) for c in grid["cells"].values()),
       str([(k, v["recipe"]) for k, v in grid["cells"].items()]))
    ok("a renamed constant is REFUSED, not defaulted",
       refuses(lambda: _scalar("originY = 4,\n", "originX", "test")))
    ok("a Grid with the wrong cell count is REFUSED",
       refuses(lambda: parse_grid(_read(GRID_LUAU).replace('id = "A1"', 'id = "A9"', 1))))

    # THE FOOTPRINT AND THE TILING, against Grid's own published numbers.
    fp = geo.footprint()
    ok("the footprint is 4490 x 2986 studs",
       abs(fp["maxX"] - fp["minX"] - 4490) < 1e-9 and abs(fp["maxZ"] - fp["minZ"] - 2986) < 1e-9,
       "%s" % fp)
    # Grid.flankFirstStuds' OWN COMMENT names the convergence: "bend 45/60  340 -> 365 -> 366 -> 366".
    ok("flankFirstStuds converges to Grid's own 366", abs(geo.flankFirstStuds() - 366) < 1e-9,
       fmt(geo.flankFirstStuds()))
    ok("standCount is 15", geo.standCount() == 15)

    for pps in (0.40, 0.55, 0.70, 1.0):
        plan = tile_plan(geo, pps)
        ok("the tiling is exact at %.2f px/stud" % pps, not check_tiling(plan),
           "; ".join(check_tiling(plan)))
        ok("nine tiles at %.2f px/stud" % pps, len(plan["tiles"]) == 9)
        ok("no tile is over %d px at %.2f px/stud" % (TEXTURE_MAX_PX, pps),
           all(max(scaled_size(t["box"])) <= TEXTURE_MAX_PX for t in plan["tiles"]))
        # THE WHOLE POINT: a tile's world rect, read back from its rounded pixel box, must place
        # every landmark at exactly the pixel this script painted it at.
        worst = 0.0
        for mark in landmarks(geo, plan):
            tile = next(t for t in plan["tiles"] if t["id"] == mark["tile"])
            rect = tile["rect"]
            fx = (mark["worldX"] - rect["minX"]) / (rect["maxX"] - rect["minX"]) * mark["outW"]
            fy = (rect["maxZ"] - mark["worldZ"]) / (rect["maxZ"] - rect["minZ"]) * mark["outH"]
            worst = max(worst, abs(fx - mark["pxX"]), abs(fy - mark["pxY"]))
        ok("a tile rect round-trips every landmark at %.2f px/stud (worst %.3e px)" % (pps, worst),
           worst < 1e-6, "%.6f px" % worst)

    plan = tile_plan(geo, 0.70)
    marks = landmarks(geo, plan)
    ok("every C1 stand, every cell corner and 36 road samples are landmarks",
       len([m for m in marks if m["name"].startswith("stand")]) == 15
       and len([m for m in marks if m["name"].startswith("corner")]) == 32
       and len([m for m in marks if m["name"].startswith("road")]) == 36, str(len(marks)))
    ok("no landmark falls outside its tile",
       all(-1e-9 <= m["pxX"] <= m["outW"] + 1e-9 and -1e-9 <= m["pxY"] <= m["outH"] + 1e-9
           for m in marks))

    # THE MANIFEST, and that a missing id file means zeros rather than a guess.
    sizes = dict((t["id"], scaled_size(t["box"])) for t in plan["tiles"])
    text = manifest_luau(plan, geo, {}, sizes)
    ok("the manifest writes assetId 0 for a tile with no id", text.count("assetId = 0,") == 9)
    text = manifest_luau(plan, geo, {"C1": 123}, sizes)
    ok("the manifest writes the id it is given", "assetId = 123," in text)
    ok("the manifest names the generator and the note",
       "tools/map_paint.py" in text and "2026-11-12-painted-map-images.md" in text)

    # A TINY PAINT, so the renderer itself is exercised offline.
    try:
        small = paint_canvas(geo, tile_plan(geo, 0.06), verbose=False)
        ok("the canvas paints at a tiny resolution", small.size == tile_plan(geo, 0.06)["canvas"],
           str(small.size))
    except Exception as error:                                    # noqa: BLE001 - reported, not hidden
        ok("the canvas paints at a tiny resolution", False, repr(error))

    print("[map-paint] selftest %s: %d checks, %d failed"
          % ("FAIL" if fails else "PASS", len(ran), len(fails)))
    return 1 if fails else 0


def refuses(thunk):
    try:
        thunk()
    except Refused:
        return True
    except Exception:                                             # noqa: BLE001
        return False
    return False


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("check", "render"):
        one = sub.add_parser(name)
        one.add_argument("--pps", type=float, default=0.70,
                         help="px per stud of the painted canvas (default 0.70)")
        if name == "render":
            one.add_argument("--out", default=None)
            one.add_argument("--ids", default=None,
                             help="JSON of tile id -> Roblox asset id (default assets/ready/map/asset-ids.json)")
    sub.add_parser("selftest")
    args = parser.parse_args(argv)
    try:
        if args.command == "check":
            return cmd_check(args)
        if args.command == "render":
            return cmd_render(args)
        return cmd_selftest(args)
    except Refused as error:
        print("[map-paint] REFUSED: %s" % error)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
