# The Threshold

Design, 1 October 2026. Status: **approved, in progress**. This is the second complete monument. It uses [Spatial Links](2026-10-01-spatial-links.md) as one tool among the others; it is not a second link study.

> **A closed tower whose entrances only exist when its outer shell, your position and your line of sight agree.**

- **The Ring** asks: *which side must I be on before I move the structure?*
- **The Threshold** asks: *from where must I observe the structure before the useful connection becomes visible?*

Each mechanic has its own job:
- **Physical traversal:** docking, riding, and a gravity curl inside the tower.
- **Turning:** two alignments of one sleeve, needed at different times from different places.
- **Links:** the only way into the closed core, and out to a hidden balcony.

## Pieces

Dimensions are at ×1; the monument is built at ×4 ([monumental scale](2026-10-01-monumental-scale.md)). Directions are world directions: west is −x, south is +z. Radius r is measured from the tower axis.

| Piece | Moves | Role | Geometry (×1) |
|---|---|---|---|
| **Entry** | fixed | start, under a warm lantern; the **Gate** doorway at its far west end ("you arrived through it") | deck x −17 → −9, width 4, top y 0 |
| **Sleeve** | turns about Y, 4 states, carries the player | pale stone shell, open at the top, with a moving accent band | 16 box segments, r 6.0 → 6.6, y −2 → 9 |
| **Ledge** (on the sleeve) | with the sleeve | walkable; docks with the entry only in state 0 (west). The **Ledge door** stands at its inner edge, in front of the sleeve's **low window** | r 6.8 → 9.0, 4 wide, top y 0; window 1.2 wide, y 0 → 2.2 |
| **High opening** (in the sleeve) | with the sleeve | faces north in state 0 and east in state 3 | 1.4 wide, y 5.8 → 8 |
| **Core** | fixed, closed (no door) | dark stone, taller than the sleeve; a **low slit south** and a **high slit east** | 16 box segments, r 3.4 → 4.0, y −6 → 13; slits 0.9 wide; low y 1.2 → 3, high y 6 → 7.6 |
| **Slab** (inside the core) | fixed | **underside** (walked upside down) carries the **Under door** on its south edge; a 180° curl at its west end leads onto the **top**, whose east edge carries the **High door** facing the high slit | x −1.4 → 2.4, width 1.6; top y 6, underside y 4, curl radius 1 |
| **Balcony** | fixed, outside the sleeve, high, east | the **Balcony door** at its west edge, the goal, and a beam rising far above the tower (visible from the start). Its deck hides the door from below, and side walls hide it from the sides | x 6.9 → 10.1, width 4, top y 6 |

The sleeve's states turn it by 90° about +Y. A local direction d rotated to state k is d·R(90°k). For the doors and openings this gives:

| State | Ledge (and low window) | High opening | Docked to entry |
|---|---|---|---|
| 0 | west | north | yes |
| 1 | **south**, facing the low slit | west | no |
| 2 | east | south | no |
| 3 | north | **east**, facing the high slit | no |

## Sight lines (the puzzle)

Line of sight is analytic, against box solids. Doorways are seen from either side.

| From (link pose) | Sees | Only in state |
|---|---|---|
| Gate | Ledge door | 0 |
| Ledge door | Under door, through the window and the low slit | 1 |
| High door | Balcony door, through the high slit and the high opening | 3 |

**Never:**
- the Under, High or Balcony door from the entry or the ledge;
- the Balcony door from the slab underside.

The moment of discovery comes from the architecture before the interface responds:
- The core interior is lit (a cool lamp band on the inner wall behind the Under door).
- The sleeve's openings have **warm** rims; the core's slits have **cool** rims.
- When an opening lines up with a slit, the rims sit one inside the other and a lit stripe of interior appears with the door in it.
- The link UI is unchanged: a doorway is a candidate only while you stand at a source. The first playtest showed that holding back feedback hurts, so link affordances are not delayed.

## Doorway identity

- **Labels are place names, not letters:** Gate, Ledge door, Under door, High door, Balcony door. The prompt reads "F  Link Ledge door ↔ Under door".
- **Signs are shapes** (disc, diamond, inverted bar, two bars, ring). They are blockout stand-ins for future architectural identities: a warm arrival gate, a diamond-motif door, an inverted narrow threshold, a barred high threshold, a goal-light threshold.
- The letters A, B, C, U, D appear only in this document and in the tests.

## Solution

**Intended:** 3 turns, 2 links, 2 crossings, plus walking.
1. Walk from the entry onto the docked ledge and stand at the Ledge door.
2. Ride the sleeve one turn to state 1. The window lines up with the low slit: the Under door appears inside, hanging upside down under the slab.
3. Link the Ledge door to the Under door and walk through. You arrive upside down under the slab.
4. Walk west to the curl and over it onto the slab top. Walk to the High door.
5. Turn the sleeve twice, from inside, to state 3. The high opening lines up with the high slit, and the Balcony door appears.
6. Link the High door to the Balcony door (the old link goes dark) and walk through to the light.

**Alternative order, kept on purpose:**
1. Link the Gate to the Ledge door from the entry in state 0.
2. Turn to state 1 from the entry.
3. Walk through the Gate: you come out of the Ledge door, now on the south side, walking away from the tower.
4. Turn around: the window and the low slit line up behind the door. Link to the Under door and continue as in the intended solution.

Both orders rest on the same rule: **a link survives when its threshold moves.**

**Abstract solver** (states: sleeve state, piece, doorway stood at, link pair):
- minimum 7 actions (3 turns, 2 links, 2 crossings);
- unsolvable without links;
- unsolvable without turns;
- if the ledge could not carry the player, the minimum would be 9 actions (3 turns, 3 links, 3 crossings).

## Dead ends (all recoverable)

- **Searching the entry for a way in.** The core has no door, and the sleeve hides it.
- **Lining up the high opening from outside.** It shows nothing from there: the same alignment means nothing from one place and everything from another.
- **Turning from the entry**, which strands the ledge. Turning back docks it again. Alternatively, link the Gate to the Ledge door in state 0, before turning.
- **Turning the wrong way inside.** Keep turning.

## §16 template

- **Expected first idea:** find a door into the tower.
- **Why it is insufficient:** the core has none, and the sleeve hides the inside.
- **Required discovery:** what each alignment of the sleeve shows, and from where.
- **Unique to Elsewhere:**
  - the same moving shell gives two different connections, depending on where you stand;
  - gravity changes inside the closed tower;
  - links survive the structure's movement.

## Playtest

**Success criterion:** the player says, in their own words, "rotating the sleeve isn't opening doors; I'm lining up openings so I can see and connect through the fixed core."

Questions:
1. In isometric, do the sleeve and the core read as two structures, one turning around the other?
2. Is the goal beam noticed from the start, and does it frame the problem ("how do I get up there")?
3. At the Ledge door after the ride, which comes first: noticing the lit stripe, or the doorway highlight?
4. Inside, does the player think of turning the sleeve again from where they now stand?
5. Does anyone find the alternative order, and does it feel like a discovery rather than a cheat?
