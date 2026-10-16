# The shop window: a side menu, a turning picture, and the words beside it

2026-10-16, task 196. **Written DURING the task and not before it, which is a deviation from rule 1
and is stated rather than hidden:** the dispatch is a REDRAW of an existing owner (`Hud.ShopPanel`,
tasks 178 and 181) with the layout named in it, Karen is waiting at the screen, and the one genuinely
new technique -- a `ViewportFrame` with a model in it -- was settled by measurement in the running
client rather than by reading. What the note records is the sources, the pattern, the numbers, and
the three things the documentation would not tell a fetcher.

Karen, 2026-10-15 ~17:40, verbatim (via the Director, outside the repo):

> menus for buying things has to be better more nicer like side menu with click and then shows in
> right side image and explanation what is that

## 1. What the system must do

1. A **side menu** on the left: every catalogue item, under a category header (Weapons / Ammo /
   Licences / Clothing), each row carrying its name, its price and one badge (OWNED / SOON / n HUNTS
   / NO COINS).
2. **Click a row, and the right-hand column becomes that item's page:** a large picture of the thing
   itself, its name, a sentence saying what it does in the game, the price in coins, the unlock rule,
   and ONE big button reading BUY / OWNED / n HUNTS / NO COINS.
3. The **coin balance at the top**; a way out at any time (`X`, or walking away from the counter).
4. **The same server-authoritative buy path.** Nothing about what a thing costs, whether it is owned
   or whether it may be bought moves to the client (task 178's security, unchanged).
5. **It must fit a phone**: 400 x 800, every tap target over Roblox's 44 px minimum.
6. **No uploads.** Karen's time, not Meshy credits: the picture has to come out of what the game
   already has.

## 2. Sources

| Source | Licence / status | Does well | Does badly |
|---|---|---|---|
| **Apple HIG, Split views** <https://developer.apple.com/design/human-interface-guidelines/split-views> | Apple's own documentation, maintained (current HIG) | States the master-detail contract in one line -- a primary column listing items, a secondary column showing the selected item -- and the small-screen rule: ONE selection, and the detail pane is never empty | iPad-shaped. Says nothing about a 376 px panel inside a game HUD, nothing about gamepads, and its collapsing behaviour assumes a navigation stack this Hud does not have |
| **Material Design 3, canonical layouts: list-detail** <https://m3.material.io/foundations/layout/canonical-layouts/list-detail> | Google, maintained; docs content public, code Apache-2.0 | Gives the layout as NUMBERS rather than as a picture: a list pane around a third to two-fifths of the width, a detail pane that takes the rest, and a 48 dp minimum touch target. That is where `LIST_FRACTION = 0.4` and the 48/56 px row heights come from | Written for dp on Android with a window-size-class system this engine has no equivalent of; its "compact" advice is to show ONE pane at a time, which is exactly what Karen asked us not to do |
| **Roblox `ViewportFrame`** <https://create.roblox.com/docs/reference/engine/classes/ViewportFrame> | First-party reference, maintained, Roblox Terms | It is the only way to draw a MODEL inside a `ScreenGui`, and it carries its own camera and its own three lighting properties, so a shop picture needs no part in the world and no upload | **The page renders to a fetcher as a property INDEX with no prose** (fetched 2026-10-16: `CurrentCamera`, `LightColor`, `LightDirection` and `Ambient` are listed with no explanatory text, and nothing on the page says which classes fail to render). So the three facts this task rests on were MEASURED in the running client instead -- section 4 |
| **ioquake3 `bg_itemlist`** (`code/game/bg_misc.c`) <https://github.com/ioquake/ioq3> | GPL-2.0, maintained | The catalogue's own pattern, already adopted in task 178: items as one static literal table read by both sides. This task adds two fields to it (`category`, `blurb`) rather than inventing a second table for the menu | Says nothing about drawing. Quake's shop is a pickup, not a window |
| **This repo, `Hud.MapUi` and `Hud.ReportPanel`** | ours | Both have already REFUSED a `ViewportFrame`, with written reasons, and both reasons are on the record to be checked against | Neither reason survives here, and that had to be argued rather than assumed -- section 3 |

## 3. The pattern adopted, and why

**Master-detail (split view), with the selection held as an ITEM ID.** The list is a
`ScrollingFrame` + `UIListLayout` of pre-built rows; the detail pane is a `ViewportFrame` plus five
labels and one button, all built once and *written* per render.

Three decisions are worth the ink:

1. **The picture is a `ViewportFrame` holding the game's own model, not an uploaded image.** This
   repo has twice decided against a viewport and both reasons were re-read: `MapUi` refused one
   because *"a `ViewportFrame` cannot render Terrain"* (a map IS terrain), and `ReportPanel` refused
   one because *"a 104-px picture of a boar does not need a camera and a `ViewportFrame` per row
   would be eight of them"*. Here there is ONE viewport, for ONE selected item, alive only while the
   panel is open -- and what must be shown is a rifle, which no `Frame` and no `UICorner` can draw.
   The alternative was an upload per item: Meshy credits, Open Cloud moderation and Karen's OK, for
   five pictures that would then be wrong the next time the rifle changed.
2. **The rifle in the window is drawn from `Rifle.Geometry.pieces`** -- the same pure piece list
   `Camera.Viewmodel` draws in the player's hands and `Weapon.Hardware` welds onto the Tool in the
   world -- with the published meshes where they have arrived and the measured fallback boxes where
   they have not. That makes `Hud.ShopDisplay` the THIRD drawer of one geometry, which is the
   arrangement those two already established, and not a third opinion about the shape of the gun.
   **Nothing in the new file computes a coordinate of the rifle**; the two rungs of Karen's ladder
   differ only by `SIGHT = "bead"`, which is task 143's own filter.
3. **The selection is an id and the detail pane is redrawn from the CURRENT payload every render.**
   A pane filled in at click time is the stale-state bug this project is named after (two correct
   pieces of code disagreeing): a balance that changes while the panel is open -- a drive paying out,
   a purchase completing -- has to change the big button with it. The client spec asserts exactly
   that, with nobody clicking between the two states.

Rejected: a second `ScreenGui` (one Hud, one place for a visibility audit); a per-row BUY button
(five ways to spend money by accident, and no room for a picture); reading the blurb off the shared
catalogue in the panel (the price already travels on the wire, so half-and-half would be two readers
of one row).

## 4. What was measured rather than read

* **The `ViewportFrame` renders through its OWN `CurrentCamera`.** The docs page carries no prose on
  it, so the camera is created as a child of the frame and assigned, and the client spec asserts both
  (`CurrentCamera` is set, and it is a descendant of the frame) -- a viewport with no camera is the
  flat rectangle `docs/PROJECT_CONTEXT.md`'s *"certified a blank screen twice"* warns about.
* **A `SurfaceGui` does not render inside one**, so the licence card is drawn out of coloured blocks
  (a green header, a dark photo square, three ink lines) instead of out of text on a surface. Stated
  as the reason in the code rather than as a style choice.
* **The vertical arithmetic, and it changed the design.** At 1920 x 1080 the detail column is 384 px
  wide, so a picture at `IMAGE_FRACTION = 0.56` is 210 px tall -- and with the name, the price, the
  unlock line and a 52 px button under it there were **ten pixels** left for Karen's explanation.
  Hence `IMAGE_MAX_FRACTION = 0.42`: the picture is capped by the column's HEIGHT as well as its
  width. Measured again after the cap: 5 lines of blurb on a 400 x 800 phone, 3 on a monitor.
* **How long an explanation may be.** At 12 px in `Enum.Font.Code` a glyph is about 7.2 px wide, so
  the phone's 200 px pane holds ~27 characters a line and the ~104 px above the button holds 5 lines:
  **135 characters**. `Shop.CONFIG.PANEL.BLURB_MAX` is that number and `Shop.rowsOk` REFUSES a longer
  row, so a sentence that would be clipped on a phone fails the harness instead of looking fine on a
  monitor. The longest in the catalogue today is 124.

## 5. The numeric targets

| Thing | Number | Where it comes from |
|---|---|---|
| Panel | `360`..`640` wide, up to `470` tall, 12 px gutter | 360 is task 178's measured phone width (design 13.1); 640 is a window, not a wall |
| List pane | 40 % of the body, clamped to 132..220 px | Material 3's third-to-two-fifths; 132 is what holds "BEATER LICENCE" at 14 px |
| Menu row / header / button | 56 / 22 / 48 and 52 px | Over Roblox's 44 px touch minimum and Material's 48 dp |
| Picture | 56 % of the detail width, 42 % of the column height, 100..210 px | Section 4 |
| Explanation | <= 135 characters, 5 lines on a phone | Section 4 |
| Spin | 24 deg/s, one turn in 15 s | A turn you can read is a turn you do not notice |
| Lens | 28 degrees, framed at 1.12 x the item's bounding radius | A narrow lens is a catalogue photograph; at 70 a rifle 2 studs away bends like a fish-eye |
| Cost while shut | one `if` per frame | `ShopPanel.step` returns before it writes anything unless the panel is open |

## 6. What this note cannot tell you

Whether it LOOKS nicer. That is one screenshot (rule 5), inspected, and then Karen's own look --
which is the whole shape of her 2026-10-15 loop. The spec can prove the selected item's model is in
the viewport with its parts and its camera aimed at it; it cannot prove the rifle is the right way
up, and after tasks 188-190 that is a thing to look at rather than assume.
