# Monumental scale

Design, 1 October 2026. Status: **implemented** ([plan](2026-10-01-monumental-scale-plan.md)); not yet hand-playtested. Changes made during implementation: turn sweeps sample every **0.25 m**, not 0.1 m (0.1 m was too slow for Q/E, and the thinnest solid is 0.26 m); the overview camera stands **3×** the framing away and the backdrop starts at **600 m** (at 6× the camera stood inside a backdrop mass); light lines keep their thin, low profile while their lengths scale. Applies to The Ring (rebuilt at ×4) and to every later monument (authoring rules).

## Why

Played in first person, The Ring feels barely bigger than the player. The spec asks for the opposite: *"A compact structure in isometric view may feel monumental at eye level"* (§6). In first person *"the player may no longer recognize the whole object"* (§23).

Throwaway in-engine probes compared the same viewpoints under several treatments:

| Treatment | Effect from first person |
|---|---|
| Sky gradient, depth fog, FOV 60 | More depth; the monument is no bigger |
| Tower and piers running into haze above and below | Strong when looking up or down; nothing changes straight ahead |
| Far layered world, 450–1600 m away | Real depth when looking out |
| Colossal enclosure 70 m away | Worse: reads as the walls of a room |
| Tower flaring above and below the ring | Good isometric silhouette; barely visible from first person |
| Whole monument ×4, player unchanged | **The only treatment that made the near field feel big**: a small figure on a wide deck, beside a tower wider than the view |

Decisions:
- the monument is rebuilt at **×4**;
- **walking speed rises** to keep a pass reasonable;
- the atmosphere and far world become a **reusable kit**, because they add depth at every scale.

## 1. Atmosphere kit (all monuments)

- **Sky and fog.** A procedural sky gradient (dark zenith, hazy blue-grey horizon). Depth fog starts at ~60 m and is thick by ~1.6 km. A soft mist layer lies far below (~−60 m), so the void has depth instead of a floor. Verified in the Compatibility renderer.
- **Overview environment.** The isometric camera gets its own copy of the environment, with fog pushed beyond the composition. The puzzle stays crisp; the world behind it fades.
- **Backdrop scene.** A new `world/backdrop.tscn`: about 25 authored megastructure silhouettes 450–1600 m away, rising out of the mist. It is scenery with no gameplay, built as scene data (no runtime generator). A new `ElsewhereLevel.backdrop: PackedScene` field selects it, defaulting to the shared backdrop.
- **FOV.** The default drops from 72° to 60°. The 60–95 setting stays.

Accents, materials and the final background world (§24–30) remain out of scope. The kit gives scale and depth, not final art.

## 2. The Ring at ×4

### Rebuild

The generator moves into the repo as `tools/gen_ring.py`, with one `SCALE = 4`. Everything authored about the monument scales with it:
- decks and walk regions;
- socket positions and widths;
- rotor arms;
- gravity-curve radii;
- the tower, its cavity, doors and sightline slot;
- art meshes, lights and guide lines;
- the composition focus and size.

The player, eye height and locomotion rules do not scale. The level revision goes to **4**, so Ring saves reset once.

| | Now | ×4 |
|---|---|---|
| Walkway width | 1.6 m | 6.4 m |
| Tower | 4.8 m wide, 18 m tall | 19 m wide; runs ~200 m into haze above and below |
| Tower doors | 1.2 × 2.4 m | 4.8 × 9.6 m portals |
| Ring | 13 m across | 52 m across |
| Tower curl | radius 1 m (walked at 1.9 m/s) | radius 4 m (full speed) |
| Terrace curve | radius 2 m | radius 8 m |
| Walking route per pass | ~36 m | ~145 m |
| Piers | short | drop ~200 m into the mist |

The puzzle is unchanged: same pieces, rotors, sockets, connection table and solution (6 turns, 16 solver actions).

### Movement

- **Walk speed** 3.2 → **4.5 m/s** (`core/locomotion.tres`), about 32 s per pass. The accel and decel times are re-checked so stopping stays within the bench's stop threshold. Raise the decel rate rather than relax the threshold.
- **Rotor turns** slow from 1.0–1.2 s to about 1.8 s, so the masses feel heavy. Reduced motion still makes them instant.
- **Gravity curves** are all ≥ 4 m, so the comfort cap never slows the player in The Ring. It stays for future tight curves.

### Isometric view

- Same azimuth and elevation; the framing size and focus scale ×4.
- **Camera distance becomes a level property**, derived from the framing (at least 4× the framing size) with a matching far plane. Today's fixed 58 m would put the orthographic camera inside the 200 m tower.
- **Player marker:** at ×4 the figure is tiny against the composition. In isometric only, the traveller and its silhouette are drawn scaled by the framing size relative to a 36 m reference, so the marker keeps today's on-screen size. First person never sees it.
- **Zoom limits** (0.4–1.6) and the pan limit stay relative to the framing, so they need no change. Check that 0.4× still hides the tower interior.

### Engine limits that scale must not break

- **Sweep sampling.** Turns are sampled every 1.5° of rotation. At r ≈ 60 m that leaves 1.6 m between samples, which can step over a thin obstruction. Sample by **arc length** instead: enough samples that the farthest solid point of the structure moves ≤ 0.1 m between samples, with today's 60-sample minimum.
- **Sweep tolerance.** Each box is shrunk by an absolute 0.04 m before the overlap test. At ×4, the docking overlaps measured at ×1 grow ×4 (up to ~0.26 m). Add `ElsewhereLevel.sweep_tolerance` (default 0.04 m; The Ring: 0.16 m) instead of hand-retuning the necks. The tolerance hides construction contact at docking edges, never real overlaps. The existing "blocked sweep" fixture must still block.
- **Body and eye tests stay absolute** (player size): `pose_is_clear` padding, the 0.1 m eye clearance and the 0.04 near plane do not change.
- **Socket tolerances** (`position_tolerance` 0.03, apertures) are absolute. The generated positions are exact multiples, so they still match; the tests confirm it.

## 3. Authoring rule: monument scale

Added to `docs/authoring.md`, plus a short spec addition in §23:

- Walkable decks are **≥ 6 m** wide unless a narrow passage is the point. Then make it visibly a passage between large masses.
- Structural masses (towers, rings, frames) are **many times the player**: tens of metres. A mass the player can see past at a glance is too small.
- Doorways are portals sized to the masses, not human doors.
- Gravity curves have radius **≥ 3 m**, so they are walked at full speed.
- Masses continue beyond the playable band (into haze above and below) wherever it does not obscure the isometric composition.
- A new monument is authored at this scale from the start; never scale it up afterwards.

## 4. Verification

- **Puzzle:** minimum still 6 turns / 16 actions; the 16-configuration connection table and tower necessity are unchanged; all ring, graph, camera, selection, runtime, socket, interaction, fixture and curve cases pass. Test distances (`walk` metres) scale with `SCALE`.
- **Locomotion bench** passes at 4.5 m/s. It also reports the route's walking time per pass (expected ~32 s).
- **Eye-clearance probe:** 0 clipping places in all 16 configurations. **Deck test** passes.
- **Turn sampling:** a test confirms the farthest solid point moves ≤ 0.1 m between samples for both rotors.
- **Screenshot checklist:**
  - the isometric start composition still hides the interior;
  - the upper door reads as a passage;
  - the lower-door sightline shows the balcony light;
  - the upside-down composition shows where you are;
  - the isometric marker is readable;
  - plus a first-person entry shot and a behind-the-player shot showing the scale.
- **Human check:** walk the route once at ×4 and say whether it now feels monumental and whether a pass feels too long.

## Out of scope

- Final materials, surface detail and the full background world (§24–30).
- A run or sprint key (§6; revisit only if 4.5 m/s still feels slow).
- Rescaling the test fixtures (Bell Cradle, Folded Observatory). They stay at ×1 as mechanical tests, which also proves the engine works at both scales.

## Risks

- **Walking time.** Dead ends and walking back now cost ~4× the distance. If playtests show tedium, shorten runs where the radial layout allows before raising speed further.
- **Composition at ×4 with tall masses.** The 200 m tower must not crowd the isometric frame. If it does, fade the masses' far ends in the overview environment rather than shortening them.
- **Performance.** Larger fog and far-plane distances, and a backdrop of about 25 large boxes, are cheap. Shadow distance needs tuning so the near field keeps crisp shadows at the new scale.
