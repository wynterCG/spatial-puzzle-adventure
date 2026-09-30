# Elsewhere ? positioning prototype specification

Revision 5, 30 September 2026.

## Core direction

The central question is **Where do I need to be before I transform the space?** A solution depends on structure configuration, player position and action order. Walking then rotating is not interchangeable with rotating then walking. Isometric manipulation and inhabited traversal must both contribute.

Impossible geometry is optional. The default prototype contains three small physical puzzles using marked paths, surface-relative gravity, curved transitions and rotating structures. No portal, new lever, inventory item or milestone lock is required to complete them. The earlier impossible gallery remains available as a separate experiment, not the foundation of the new route.

These studies test whether players can explain a dependency, not just reproduce a successful sequence. Their logical dependencies are implemented and mechanically checked; whether people find them engaging and understandable still needs blind playtesting.

## Shared traversal and manipulation

- Third person is the default traversal mode; first person remains available in settings.
- Ivory paving identifies authored walkable regions. Architectural mass is not automatically a path. Ordinary edges stop the character; there is no arbitrary edge wrapping, jumping or falling puzzle.
- The rounded ribbons are explicit gravity transitions. Contact, normal, heading and local orbit are transported continuously around a radius-3 half-circle. A configurable straight tail joins the next path without overlapping its paving.
- Moving structures carry the same local player contact and orientation. Walking is disabled while a turn is in progress.
- A connection requires coincident authored endpoints (within 0.03 units) and matching world normals. The existing walker also checks the actual attempted contact against both walking regions. Configuration integers alone never enable links.
- Small end inlays become teal when they join. The HUD reports the current ground and its neighbours; there is no automatic solution overlay.
- Each turn samples the complete swept geometry against other structural boxes and checks the passenger/body clearance. Oriented-box tests use 0.04-unit construction clearance at docking edges. The docking carrier has a recessed structural slab at its hinge, beneath the shallow paving lip.
- A rejected turn leaves the arrangement, player and undo history unchanged. Feedback identifies an obstruction; requested hints provide progressively more explicit reasoning.
- Turns are quarter rotations over 0.8 seconds, or atomic with reduced motion. The entire moving assembly shares a pivot. There are no new manipulation locks or forced interaction sequences.

## Study 1 ? Choose your deck

**Question:** Which path needs to carry you?

The entrance meets a short upper deck. A fixed rounded walkway leads to a lower landing and a separate, longer underside deck on the same carrier. Both decks rotate around a shared horizontal axis, but the traveller cannot change between them aboard the carrier.

The exit lies at the long deck's far end after a half-turn. The short deck ends early and never joins the exit, regardless of the carrier's orientation. The carrier can be correctly arranged while the traveller remains on the wrong path.

**Intended solution:** use the fixed curve to reach the lower landing; board the long deck; roll twice; walk to the light.

**Why the order matters:** a rotation transports the chosen path, not the player onto another path. Rotating the empty carrier first removes the lower boarding connection. Undo or returning the carrier restores it.

Physical layout: carrier pivot (0, -2, 0); upper walking plane Y=1 and underside plane Y=-5 before rotation; short deck spans X=-6 to 2, long deck X=-6 to 6. Both initially lie at Z=-2. The fixed exit begins at X=6, Y=1, Z=2. The entrance curve's tail is 2.2 units so it meets the lower landing's edge cleanly.

## Study 2 ? The quiet landing

**Question:** Where can you stand while the carrier changes?

A rotating assembly holds two separated radial paths at different gravity planes. The upper first path joins the entrance; the lower second path reaches an inward-facing goal. The goal cannot be reached from the first path at any orientation, and the entrance cannot board the second path directly because their grounds differ.

A fixed landing and rounded ribbon provide the only transfer between the two paths. The landing stays still while the assembly turns beneath it. Its curve reaches the second path's gravity plane.

**Intended solution:** board the first path; turn once toward the fixed landing; step off; turn the empty assembly again; follow the fixed curve onto the second path; walk inward to the light.

**Why the order matters:** remaining aboard the first path carries the traveller away from the fixed transfer. Turning from the entrance cannot make the lower path share its gravity. The player needs a stationary place from which to change paths.

The first path occupies radius 3 to 6 at Y=3; the second occupies radius 1 to 6 at Y=-3 and faces downward. The fixed landing lies beyond the northern docking point. Its rounded path changes gravity through six units of height. A compact cross-shaped goal platform meets the second path's inner end.

## Study 3 ? Prepare the receiver

**Question:** What needs to move before the dock closes?

The player boards a carrier from a world-vertical starting path. A quarter rotation about Z brings it onto the receiver's horizontal gravity plane. Brass docking arms travel with the carrier. A separate L-shaped receiver turns about Y and leads to the exit.

The receiver can be arranged while the carrier is withdrawn. Once the carrier docks, its visible arms occupy the receiver's turning clearance. Both clockwise and counterclockwise routes into or out of the aligned receiver encounter those arms. This is an oriented-geometry sweep rejection, not a rule keyed to a particular configuration or a hidden lock.

**Intended solution:** arrange the receiver first, then ride the carrier into the prepared connection and walk through the L-shaped path to the light.

**Why the order matters:** the useful receiver rotation needs clearance which docking consumes. Boarding can happen before or after preparation; the required ordering is receiver preparation before carrier docking. A premature dock remains recoverable by withdrawing the carrier.

## Camera direction

The user's latest correction intentionally separates the two views:

- **Third person defaults to world alignment.** The screen uses world up; the character can appear sideways or upside down. Mouse yaw uses a world-aligned orbit heading instead of inheriting each support rotation. If that arm would enter a floor, obstruction handling places it on the clear side of the surface while retaining world-up screen orientation. This can reposition the camera near obstructions and still needs human comfort testing.
- **Isometric view provides orientation.** It remains above the occupied ground with a consistent local angle. The studies use offset (30, 40, -30) in the transported contact frame. Matching seams preserve world azimuth even when the adjoining pieces have different local axes. Walking heading never chooses a camera side. No free overview orbit is added.
- A setting restores surface-following third person. First person remains optional and keeps its surface-relative look. Follow distance (3?8), sensitivity and reduced motion remain available. Reduced motion skips transformation animation; it does not eliminate orientation changes caused by walking around a curve.

No camera orientation activates puzzle connections. The shared avatar silhouette remains an overview-only fallback for occlusion.

## Interface, progression and recovery

The project starts in Study 1, or restores the active study's settled save. Escape opens study selection and camera settings; all three studies are available for comparison without completion gates. The completion panel asks the study's causal question. The player can then choose to reveal the intended explanation, retry, or continue.

| Action | Default |
|---|---|
| Walk / look or orbit | WASD / mouse |
| Architectural / traversal view | Tab |
| Select moving structure | 1 / 2 or panel buttons |
| Quarter-turn | Q / E or panel buttons |
| Undo / restart current study | Z / R |
| Escalating hint / menu | H / Escape |

Existing key preferences are imported from the shared settings file. Undo restores structure states, local contact, heading and camera frame from before a turn. Restart restores the study's initial arrangement. There are no lives or time penalties.

`positioning.save` stores the active study, arrangement, player contact, selected structure, overview frame and completion flags. It is separate from the gallery's `journey.save`. Saves occur after settled turns, undo, restart, pausing, completion, returning to the gallery, study selection and a normal window-close request. No mid-turn state is written. Headless tests neither load nor write progress.

## Optional gallery experiment

Escape ? Optional: original gallery experiment opens the earlier guided level. Its menu returns to the positioning studies. Its two local levers, rounded entrance path, carrier, turning covered gallery, two-way concealed spatial connection and contextual cutaways remain available. The floor and cover rotate together. The experiment uses its existing checkpoint format and save file.

The gallery is not needed for any of the three new studies. See [gallery-study.md](gallery-study.md) for its layout, portal implementation, narrative/art proposal and scope. The [original concept](original-concept.md) remains preserved unchanged as design input, not operational instructions.

## Scope and implementation

This is a set of three independently selectable prototypes, not a connected campaign. Geometry and sound in the retained experiment are procedural; the new studies prioritize readable paths and mechanisms. No new external assets or paid addon dependency is required to play a clone. Narrative, larger combinations, environmental dressing and production art remain future work.

- `scripts/positioning_game.gd`: layouts, physical docking contacts, swept turns, cameras, undo and study saves.
- `scripts/positioning_hud.gd`: study selection, questions, optional explanations and settings.
- `scripts/positioning_tests.gd`: solution routes, counterexamples and camera checks.
- `scripts/surface_piece.gd`, `surface_walker.gd`, `curved_track.gd`: shared path, movement and camera mechanics.
- `scripts/game.gd`, `hud.gd`, `scenes/main.tscn`: retained gallery experiment.
- `scenes/positioning.tscn`: default project entry point.

Use [playtest.md](playtest.md) to assess reasoning and comfort. Technical evidence is in [validation.md](validation.md).
