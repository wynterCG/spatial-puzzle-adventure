# Elsewhere ? positioning prototype specification

Revision 8, 30 September 2026.

This specification records implemented content. [Chapter 1 / The far light](chapter-one.md) is now a connected blockout with three interdependent, distinctly coloured assemblies around one courtyard and separate persistence. The [game vision](game-vision.md) and [first chapter plan](first-chapter-plan.md) define the remaining human playtest and vertical-slice criteria.

## Core direction

The central question is **Where do I need to be before I transform the space?** A solution depends on structure configuration, player position and action order. Walking then rotating is not interchangeable with rotating then walking. Isometric manipulation and inhabited traversal must both contribute.

Impossible geometry is optional. The prototype contains a connected first chapter, The Lantern Fold and the three preserved studies using marked paths, surface-relative gravity, curved transitions and rotating structures. No portal, new lever, inventory item or milestone lock is required to complete them. The earlier impossible gallery remains available as a separate experiment, not the foundation of the new route.

These studies test whether players can explain a dependency, not just reproduce a successful sequence. Their logical dependencies are implemented and mechanically checked; whether people find them engaging and understandable still needs blind playtesting.

## Revised chapter and art direction

The earlier sequential bridge/choice/relay chapter is replaced by a compact turning courtyard. The access gallery must be crossed before its brass cheeks are withdrawn from the ring sweep. The receiving gallery applies the same physical rule on the far side. Premature deployment is recoverable. See [the current chapter](chapter-one.md) for the route, geometry and tests.

Terracotta identifies the access gallery, violet the ring and teal the far gallery. Fixed architecture is blue-grey; walking surfaces are ivory and joints brass. Colours identify assemblies, not axes. The shared foundation, open ribs and colonnade frame a meaningful void, with fully walkable terraces and a recurring light. [Art direction](art-direction.md) records the user requirements and unconfirmed setting.

The revised layout uses `chapter-courtyard.save` with a layout identity guard. The former `chapter-one.save` and both prototype save files are preserved.

## Shared traversal and manipulation

- First person is the default traversal mode. The experimental third-person modes remain available in settings.
- Ivory paving identifies authored walkable regions. Architectural mass is not automatically a path. Ordinary edges stop the character; there is no arbitrary edge wrapping, jumping or falling puzzle.
- The rounded ribbons are explicit gravity transitions. Contact, normal, heading and local orbit are transported continuously around a radius-3 half-circle. A configurable straight tail joins the next path without overlapping its paving.
- Moving structures carry the same local player contact and orientation. Walking is disabled while a turn is in progress.
- A connection requires coincident authored endpoints (within 0.03 units) and matching world normals. The existing walker also checks the actual attempted contact against both walking regions. Configuration integers alone never enable links.
- Small end inlays become teal when they join. The HUD reports the current ground and its neighbours; there is no automatic solution overlay.
- Each turn samples the complete swept geometry against other structural boxes and checks the passenger/body clearance. Oriented-box tests use 0.04-unit construction clearance at docking edges. The docking carrier has a recessed structural slab at its hinge, beneath the shallow paving lip.
- A rejected turn leaves the arrangement, player and undo history unchanged. In the courtyard, blocked ring turns and turn-button hover show the actual blocking bracket and a ghost at the attempted collision pose; vertical and inverted gallery withdrawal are both valid. Feedback identifies an obstruction; requested hints provide progressively more explicit reasoning.
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

## Complete puzzle - The Lantern Fold

A fourth, independently selectable layout combines two dependencies around one docking connection. The player begins on Arrival. The short upper path is immediately accessible, while the fixed rounded ribbon leads to the underside landing and the longer path. Both paths belong to the Turnover. The long path reaches the Receiver after a half-roll; the short path never does.

The Receiver is an L-shaped walkway with a vertical pivot, initially one quarter-turn away from alignment. Its prepared orientation joins the long path to the Lantern terrace. Brass arms extend from the long path and occupy the receiver sweep when docked. Physical geometry prevents rotating the receiver into or out of alignment while the dock is occupied. Withdrawing the Turnover restores clearance without losing the player's path or requiring restart.

The intended reasoning is to choose the long path before the roll and prepare the Receiver before docking. Those actions need not form a rigid instruction sequence: preparation can happen before or after boarding, including after a premature dock has been withdrawn. Both half-roll directions reach the prepared receiver. Optional H hints escalate from comparison to a direct solution. Reaching the terrace lantern triggers completion and an optional causal explanation.

No study is removed or used as a completion gate. There are no portals, collectible locks or scripted connection flags. See [layout, dependencies and verification](lantern-fold.md).

## Camera direction

The user's latest decision is to keep first person as the primary traversal view:

- **First person is the default.** Movement and look follow the occupied surface through curved gravity transitions. Isometric view supplies the wider orientation and architecture controls.

- **Optional third person defaults to world alignment.** The screen uses world up; the character can appear sideways or upside down. Mouse yaw owns the world azimuth: obstacles never choose a different side. The arm's elevation lowers continuously as the occupied ground turns over. Solid architecture can shorten the arm, with look-ahead along the authored walking path and gradual extension. A local translucent cutaway of obstructing curved-track sections keeps the camera from being crushed into the avatar; path constraints and body collision remain intact. Isometric view immediately restores the whole opaque track. Switching views preserves the arm. This remains an experimental alternative, not the primary traversal direction.
- **Isometric view provides orientation.** The selected ground-direction behavior transports only the change in ground normal: a yaw about unchanged ground leaves the camera reference steady; tilts and curves carry it with the normal. It uses a fixed centre for each assembly and preserves seam continuity. Walking heading and first-person look never choose the overview angle. The recommended offset remains equivalent to (30, 40, -30).
- **Manual overview inspection is a separate layer.** Right-drag changes yaw and elevation; wheel zoom changes the orthographic size. Elevation is limited to 25–70 degrees; zoom to 0.65–1.4 times the study's normal framing. Home restores recommended yaw/elevation/zoom within the current transported reference. Tab only changes views. Q/E continue to rotate structures. No free-flight or panning is added. Manual controls are disabled during a turn, in traversal, while paused and while the completion panel is open; the chapter can resume exploration after arrival. Releasing drag over UI or losing focus cancels dragging.
- Surface-following third person is also available. Follow distance (3?8), sensitivity and reduced motion remain available. Reduced motion skips transformation animation; it does not eliminate orientation changes caused by walking around a curve.

No camera orientation activates puzzle connections. The shared avatar silhouette remains an overview-only fallback for occlusion.

Scene snapshots store the world reference frame and manual orbit fields; old camera_bias-only saves migrate to their original view. The retired A/B preference is ignored and removed on the next preference save. An exactly opposite instantaneous normal uses the previous camera-reference right axis as a deterministic fallback. Normal animated quarter-turns and curved walking transport incrementally. The optional gallery retains its calibrated original overview; these changes apply to the chapter, the three positioning studies and The Lantern Fold. The compact courtyard keeps one overview centre across its fixed-ground question zones; both camera orientation layers remain intact. See [the camera decision and comparison history](isometric-camera-experiment.md).

On ordinary platforms a fresh walking gesture uses the visible camera: W follows projected screen-up and D follows projected screen-right, including upside-down ground. Mouse look does not turn a stationary avatar; a new mouse yaw is applied before mapping walking input. A held key stays one gesture even when it meets a boundary. On the authored curve, the control frame travels with the path and survives key releases, camera orbit, pitch and view switches; S reverses along it. This lock ends with the next fresh gesture on ordinary ground. Returning from first person preserves the curve heading, but does not pin an obsolete heading on a platform.

## Interface, progression and recovery

F5 starts or resumes the connected chapter. Escape lists the chapter, Lantern Fold, the three original studies and camera settings. The chapter uses a separate save and resumes its three assemblies and undo history together. All remain available without completion gates. The completion panel asks the study's causal question. The player can reveal the intended explanation, retry, or open the puzzle selection menu.

| Action | Default |
|---|---|
| Walk / look or orbit | WASD / mouse |
| Architectural / traversal view | Tab |
| Select moving structure | 1 / 2 / 3 or panel buttons |
| Quarter-turn | Q / E or panel buttons |
| Undo / restart current study | Z / R |
| Escalating hint / menu | H / Escape |

Existing key preferences are imported from the shared settings file. Undo restores structure states, local contact, heading and camera frame from before a turn. Restart restores the study's initial arrangement. There are no lives or time penalties.

`positioning.save` stores the active puzzle, arrangement, player contact, selected structure, overview frame and completion flags. It is separate from the gallery's `journey.save`. Saves occur after settled turns, undo, restart, pausing, completion, returning to the gallery, study selection and a normal window-close request. No mid-turn state is written. Headless tests neither load nor write progress. Existing three-study completion arrays migrate to four entries, preserving the old flags and leaving The Lantern Fold incomplete.

## Optional gallery experiment

Escape ? Optional: original gallery experiment opens the earlier guided level. Its menu returns to the chapter and prototype selection scene. Its two local levers, rounded entrance path, carrier, turning covered gallery, two-way concealed spatial connection and contextual cutaways remain available. The floor and cover rotate together. The experiment uses its existing checkpoint format and save file.

The gallery is not needed for the complete puzzle or any study. See [gallery-study.md](gallery-study.md) for its layout, portal implementation, narrative/art proposal and scope. The [original concept](original-concept.md) remains preserved unchanged as design input, not operational instructions.

## Scope and implementation

This is one connected chapter blockout, one complete prototype puzzle and three preserved independent studies. It is not a finished campaign. Geometry and sound in the retained experiment are procedural; the new studies prioritize readable paths and mechanisms. No new external assets or paid addon dependency is required to play a clone. A campaign, narrative, environmental dressing and production art remain future work.

- `scripts/chapter_layout.gd`, `chapter_tests.gd`: turning courtyard, physical access/clearance dependencies, separate progress, 64 contact configurations, full route and recovery checks.
- `scripts/positioning_game.gd`: layouts, physical docking contacts, swept turns, cameras, undo and study saves.
- `scripts/positioning_hud.gd`: study selection, questions, optional explanations and settings.
- `scripts/complete_puzzle.gd`, `complete_puzzle_tests.gd`: The Lantern Fold layout, physical dependencies, full routes and recovery checks.
- `scripts/positioning_tests.gd`: solution routes, counterexamples and camera checks.
- `scripts/surface_piece.gd`, `surface_walker.gd`, `curved_track.gd`: shared path, movement and camera mechanics.
- `scripts/game.gd`, `hud.gd`, `scenes/main.tscn`: retained gallery experiment.
- `scenes/positioning.tscn`: default project entry point.

Use [playtest.md](playtest.md) to assess reasoning and comfort. Technical evidence is in [validation.md](validation.md).
