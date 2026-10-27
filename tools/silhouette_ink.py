"""Turn the four uploaded silhouette PNGs into an ink mask a spec can read.

WHY IT EXISTS: task 283's spec has to answer "does this (u, v) land on the ANIMAL in the picture",
and the picture is a Roblox asset no spec can sample. So the PNGs that were uploaded -- identified
here by the sha256 recorded in `assets/uploads.json` -- are sampled once, offline, into a coarse
grid of row strings, and `tests/client/HitCardInk.luau` is that grid.

A cell is `#` when the pixel at its CENTRE has alpha >= 128, `.` otherwise. Row 0 is the top of the
image, column 0 its left (the animal's nose: every silhouette is nose-left).

THE TRUNK BOX IS MEASURED ON THE PICTURE (task 283 round 2, Director: "the card's rectangle is
measured ON THE PICTURE, per picture -- the picture is what Karen sees"). `trunk_box` states the
rule once: the BACK LINE is the topmost row at least half as solid as the picture's solidest row,
so a mane, a raised head and antlers sit above it; the BODY'S ENDS and the HOOVES' LINE are that
trunk's own ink extent. `measure` prints the four numbers that go into `Report.CONFIG.TRUNK_IN_INK`,
and `Ink.trunkBox` in the generated file is the same rule on the 120 x 60 grid, so a spec can
re-derive the rectangle from the pixels and the two agree to a cell.

    python tools/silhouette_ink.py write     # rewrite tests/client/HitCardInk.luau
    python tools/silhouette_ink.py check     # fail if a PNG has changed (compares the GRID, not the text)
    python tools/silhouette_ink.py measure   # print each picture's trunk box, full resolution
"""

import hashlib
import os
import re
import sys

COLS, ROWS = 120, 60

# The four uploaded silhouettes, keyed by the sha256 `assets/uploads.json` records for each.
PICTURES = {
    "male": ("2c75910f400b21d0f78d47757218d181011c7c6c469729ebc7dcff70e0d63e6f", "t205-boar/boar-male.png"),
    "female": ("d27b8a6dd23fb07f258764bce9e8445c12c6a97bfeb69435066ff659ab8b6633", "t205-boar/boar-female.png"),
    "stag": ("68aab9d675782ec0e087267e11d3275d4ed07664c189a2810e5c542bb67a9470", "deer/silhouettes/deer-stag.png"),
    "hind": ("fcc9333c7c7c73a2be7d4cbddba1128ab5e1173d195b54d7cdfe124e3f499d9f", "deer/silhouettes/deer-hind.png"),
}

# The PNGs live OUTSIDE the repo (`assets/` holds no binaries). Both roots are searched.
ROOTS = [
    os.path.join(os.path.expanduser("~"), "Desktop", "driven-hunt-runs"),
    os.path.join(os.path.expanduser("~"), "Desktop", "driven-hunt-assets"),
]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tests", "client", "HitCardInk.luau")


def find(rel, want_sha):
    for root in ROOTS:
        path = os.path.join(root, *rel.split("/"))
        if os.path.isfile(path):
            got = hashlib.sha256(open(path, "rb").read()).hexdigest()
            if got != want_sha:
                raise SystemExit(f"{path}: sha256 {got} is not the uploaded {want_sha}")
            return path
    raise SystemExit(f"not found in {ROOTS}: {rel}")


def mask(path):
    from PIL import Image

    image = Image.open(path).convert("RGBA")
    width, height = image.size
    alpha = image.split()[3].load()
    rows = []
    for row in range(ROWS):
        y = min(height - 1, int((row + 0.5) / ROWS * height))
        rows.append("".join("#" if alpha[min(width - 1, int((c + 0.5) / COLS * width)), y] >= 128 else "." for c in range(COLS)))
    return rows, width, height


def spans(rows_or_alpha, nrows, ncols, is_grid):
    """(first, last, count) of the ink in every row, or None for an empty row."""
    out = []
    for r in range(nrows):
        if is_grid:
            cols = [c for c in range(ncols) if rows_or_alpha[r][c] == "#"]
        else:
            cols = [c for c in range(ncols) if rows_or_alpha[c, r] >= 128]
        out.append((cols[0], cols[-1], len(cols)) if cols else None)
    return out


def trunk_box(row_spans, nrows, ncols):
    """THE RECTANGLE THE DOTS' UNIT SQUARE IS DRAWN INTO, read off one picture's ink.

    The BACK LINE is the topmost row whose ink is at least HALF the solidest row's: above it the
    drawing is mane, raised head or antler, and a rectangle topped there would put a dorsal hit in
    the air. The body's ENDS and the HOOVES' LINE are the ink extent of those trunk rows.
    """
    counts = [s[2] if s else 0 for s in row_spans]
    solid = max(counts)
    trunk = [r for r in range(nrows) if counts[r] * 2 >= solid]
    inked = [r for r in range(nrows) if counts[r] > 0]
    return {
        "u0": min(row_spans[r][0] for r in trunk) / ncols,
        "u1": (max(row_spans[r][1] for r in trunk) + 1) / ncols,
        "v0": trunk[0] / nrows,
        "v1": (inked[-1] + 1) / nrows,
    }


def measure():
    from PIL import Image

    print("kind      u0     u1     v0     v1     (full resolution; grid gap, 1 row = %.4f)" % (1 / ROWS))
    for kind in ("male", "female", "stag", "hind"):
        sha, rel = PICTURES[kind]
        path = find(rel, sha)
        image = Image.open(path).convert("RGBA")
        width, height = image.size
        full = trunk_box(spans(image.split()[3].load(), height, width, False), height, width)
        rows, _, _ = mask(path)
        grid = trunk_box(spans(rows, ROWS, COLS, True), ROWS, COLS)
        gap = max(abs(full[k] - grid[k]) for k in ("u0", "u1", "v0", "v1"))
        print(
            "%-8s %.4f %.4f %.4f %.4f   grid %.4f %.4f %.4f %.4f   worst gap %.4f"
            % (kind, full["u0"], full["u1"], full["v0"], full["v1"], grid["u0"], grid["u1"], grid["v0"], grid["v1"], gap)
        )
    return 0


def render():
    out = [
        "--!strict",
        "-- THE FOUR SILHOUETTE PNGs' OWN PIXELS, as a grid a spec can read (task 283).",
        "--",
        "-- GENERATED by `python tools/silhouette_ink.py write` from the files that were UPLOADED,",
        "-- identified by the sha256 in `assets/uploads.json`; `check` re-derives it in CI's reach and",
        "-- fails if either side moved. It is NOT hand-written and it is not any function's output: it is",
        "-- the picture, sampled every cell centre at alpha >= 128.",
        "--",
        "-- Row 0 is the top of the image, column 1 its left -- and every silhouette is nose-LEFT, so",
        "-- column 1 is the animal's nose and the last column its tail.",
        f"local Ink = {{ COLS = {COLS}, ROWS = {ROWS}, PICTURES = {{}} }}",
        "",
    ]
    for kind in ("male", "female", "stag", "hind"):
        sha, rel = PICTURES[kind]
        path = find(rel, sha)
        rows, width, height = mask(path)
        out.append(f"-- {rel}  {width}x{height}  sha256 {sha}")
        out.append(f"Ink.PICTURES.{kind} = {{ w = {width}, h = {height}, rows = {{")
        for row in rows:
            out.append(f'\t"{row}",')
        out.append("} }")
        out.append("")
    out += [
        "-- IS THE PICTURE'S PIXEL AT THIS POINT THE ANIMAL? `u` and `v` are fractions of the IMAGE",
        "-- (u = 0 its left edge, v = 0 its top), which is what `Report.imageFit` undoes for a caller",
        "-- holding a fraction of the art frame. Outside the image is never ink.",
        "function Ink.isInk(picture: string, u: number, v: number): boolean",
        "\tlocal art = Ink.PICTURES[picture]",
        "\tif art == nil or u < 0 or u > 1 or v < 0 or v > 1 then",
        "\t\treturn false",
        "\tend",
        "\tlocal col = math.clamp(math.floor(u * Ink.COLS) + 1, 1, Ink.COLS)",
        "\tlocal row = math.clamp(math.floor(v * Ink.ROWS) + 1, 1, Ink.ROWS)",
        "\treturn string.sub(art.rows[row], col, col) == \"#\"",
        "end",
        "",
        "-- WHERE THE TRUNK SITS ON THIS PICTURE -- the rectangle a dot's unit square is drawn into,",
        "-- read off the grid above and nothing else (task 283). THE BACK LINE is the topmost row whose",
        "-- ink is at least HALF the solidest row's: above it the drawing is mane, raised head or antler.",
        "-- THE BODY'S ENDS and THE HOOVES' LINE are those trunk rows' own ink extent.",
        "-- The same rule as `tools/silhouette_ink.py` `trunk_box`, which measures it at FULL resolution",
        "-- for `Report.CONFIG.TRUNK_IN_INK`: two resolutions, one rule, so the two agree to a cell.",
        "function Ink.trunkBox(picture: string): { u0: number, u1: number, v0: number, v1: number }?",
        "\tlocal art = Ink.PICTURES[picture]",
        "\tif art == nil then",
        "\t\treturn nil",
        "\tend",
        "\tlocal counts, first, last = {}, {}, {}",
        "\tlocal solid = 0",
        "\tfor row = 1, Ink.ROWS do",
        "\t\tlocal n = 0",
        "\t\tfor col = 1, Ink.COLS do",
        "\t\t\tif string.sub(art.rows[row], col, col) == \"#\" then",
        "\t\t\t\tn += 1",
        "\t\t\t\tfirst[row] = first[row] or col",
        "\t\t\t\tlast[row] = col",
        "\t\t\tend",
        "\t\tend",
        "\t\tcounts[row] = n",
        "\t\tsolid = math.max(solid, n)",
        "\tend",
        "\tlocal back: number? = nil",
        "\tlocal u0, u1, hooves = Ink.COLS, 1, 1",
        "\tfor row = 1, Ink.ROWS do",
        "\t\tif counts[row] > 0 then",
        "\t\t\thooves = row",
        "\t\tend",
        "\t\tif counts[row] * 2 >= solid then",
        "\t\t\tback = back or row",
        "\t\t\tu0 = math.min(u0, first[row])",
        "\t\t\tu1 = math.max(u1, last[row])",
        "\t\tend",
        "\tend",
        "\treturn {",
        "\t\tu0 = (u0 - 1) / Ink.COLS,",
        "\t\tu1 = u1 / Ink.COLS,",
        "\t\tv0 = ((back or 1) - 1) / Ink.ROWS,",
        "\t\tv1 = hooves / Ink.ROWS,",
        "\t}",
        "end",
        "",
        "return Ink",
        "",
    ]
    return "\n".join(out)


def grids(text):
    """Every picture's name, pixel size and row strings, with no formatting in it."""
    out, kind = {}, None
    for line in text.replace(chr(13), "").split(chr(10)):
        line = line.strip()
        found = re.match(r"Ink.PICTURES.(@w+)@s*=".replace("@", chr(92)), line)
        if found:
            kind = found.group(1)
            out[kind] = {"rows": []}
        if kind:
            # `w`/`h` may share the marker's line (as generated) or stand alone (after stylua).
            for key in ("w", "h"):
                size = re.search(r"\b" + key + r"@s*=@s*(@d+)".replace("@", chr(92)), line)
                if size:
                    out[kind][key] = int(size.group(1))
            row = re.match(r'"([.#]+)",', line)
            if row:
                out[kind]["rows"].append(row.group(1))
    return out


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "check"
    if what == "measure":
        return measure()
    text = render()
    if what == "write":
        open(OUT, "w", encoding="utf-8", newline="\n").write(text)
        print(f"wrote {OUT} ({len(text)} bytes)")
        return 0
    have = open(OUT, encoding="utf-8").read() if os.path.isfile(OUT) else ""
    # THE GRID IS COMPARED, NOT THE TEXT: the committed file is stylua-formatted, so a byte compare
    # calls a current file stale (round 1's note). This reads both sides' `w`, `h` and row strings.
    if grids(have) != grids(text):
        print("tests/client/HitCardInk.luau is STALE: run `python tools/silhouette_ink.py write`")
        return 1
    print("tests/client/HitCardInk.luau matches the uploaded PNGs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
