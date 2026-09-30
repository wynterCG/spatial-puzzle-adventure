# Elsewhere - current game specification

Prototype revision 3, 30 September 2026. Working title.

## Authoritative design corrections

The user's clarifications supersede conflicting passages in the [original concept](original-concept.md), which remains preserved in full:

1. Third person is the default traversal view for comfort; first person is optional.
2. Movement follows **authored walkable paths**. Ordinary edges stop movement. The character cannot freely walk onto every face of a solid.
3. A moving support carries the player's local position, heading and gravity. Changing orientation requires a designed mechanism or transition; the current opening uses an occupied rolling deck.
4. The architectural view keeps a composed viewing direction but rolls with the occupied ground, making the traveller upright on screen after a configuration change. A freely orbiting overview would expose view-dependent illusions. The former separation/underside inspection control has been removed from normal play.
5. **Portal describes the spatial technique, not the visual theme.** A pair of separated endpoints becomes directly traversable through ordinary-looking architecture. The accepted arrangement activates the connection; the camera does not sustain it.

The previous mandatory underside route and automatic edge wrapping are retired. The new opening is built around these corrected rules, rather than placing invisible exceptions on the old free-surface puzzle.

## Identity and design pillars

Single-player, calm architectural puzzle adventure. Alternate between being an inhabitant and an architect. Observe, reconfigure, enter, reposition, reconfigure again, traverse and discover. Occupancy and sequencing matter: arranging the exit before boarding can remove access to the moving support.

Both views show the same world state. Rules must be predictable even when adjacency is impossible. Use architectural landmarks, clear routes and atmosphere. No axis-colour legend, default full-route overlay, required jumping, combat, precision platforming or time pressure.

## World, story and campaign

Suspended structures, distant light and intact architecture suggest a world whose relationships have drifted out of alignment. Temporary arrangements form a journey; there is no universal repaired configuration. Environmental storytelling is preferred over dialogue or inventory systems.

The intended campaign progresses through arrival spaces, moving courtyards, linked chambers and larger combinations. A later return route can revisit a visible landmark from an unexpected direction. Optional branches should reveal useful relationships or additional puzzles. These campaign regions remain proposed; only the compact opening below exists.

## Traversal and path boundaries

Every support defines one or more rectangles in its local X/Z plane at local Y = half-height. Only this authored local-UP face is walkable. Ivory paving communicates the regions; unused architectural mass is not a walking route.

Movement uses short substeps and constrains attempted movement to the region union. A path edge stops the character without changing their normal or dropping them into the void. No automatic face folding, nearest-object gravity, gap snapping or camera-dependent attachment is allowed. Footstep feedback is based on actual movement, not blocked input.

A normal cross-piece seam requires both an authored neighbour relationship and genuinely touching compatible walking regions. Links exist only in accepted settled states. Geometry and body checks also reject entry into solid architecture. Merely touching an unmarked side does not create a path.

Curved paths, stairs, arbitrary mesh navigation and explicit pedestrian gravity-transition junctions are future work. This build changes the world direction of gravity by rotating the occupied support, while the support-local walking normal remains UP.

## Cameras and comfort

Traversal defaults to a visible third-person traveller. The camera orbit lives in the support frame and follows its rotation. New movement is screen-relative; mouse motion reestablishes the screen-relative heading. The follow frame eases into changes while obstruction checks prevent it from entering the main solids and gallery walls/roofs. A clear alternative on the settled surface is used when the interpolated arm becomes severely obstructed.

Follow distance is adjustable from 3 to 8 (default 5.5). Settings include sensitivity, reduced motion, optional fixed world horizon and optional first person. No head bob or camera shake is enabled. First person hides the avatar from its own camera. Camera settings are independent of puzzle checkpoints.

The orthographic architectural camera stays at target (-1, -2, -7) plus offset (36, 30, 48), size 46. Its view direction is parallel to the gallery endpoint separation. The accepted gallery configuration makes the actual endpoints coincide in this projection. Its screen-up direction follows the occupied surface normal projected onto the image plane. During an occupied turn it rolls with the structure; turning an unoccupied mechanism leaves the camera orientation unchanged. Reduced motion holds the old frame during the short turn and cuts to the settled frame. Undo, checkpoint recovery, view switching and a new journey restore the appropriate ground frame. There is no player-controlled overview orbit or alternate depth inspection. This is a roll around the authored sightline, not an orbit that recreates identical floor foreshortening on every surface.

The architectural camera uses a cutaway: gallery roofs and the camera-facing gallery wall are omitted, including their shadows, to expose the ivory floor and the traveller. The opposite wall retains the corridor shape. The choice of wall follows each gallery's orientation during a turn. Traversal and passage-render cameras retain the complete enclosure on render layer 16. A warm silhouette of the traveller and foot ring remains a fallback when other visible structural masonry blocks the overview rays to their torso or head. It is isolated to an overview-only render layer, does not cast shadows, and is excluded from traversal and remote passage views. The remaining architecture stays opaque. This preserves character location without exposing the impossible seam; it is not a claim that camera rotation alone eliminates occlusion.

Walking pauses during architectural manipulation. Third-person view switches are cuts; optional first person retains its short transition unless reduced motion is enabled. Comfort still requires human testing.

## Current puzzle: board, roll, align, cross

### The Passenger

Start on the ivory path of the arrival platform. A fixed causeway joins the terracotta carrier when its authored deck points upward (state 0). Walk onto the carrier before changing its arrangement.

The carrier rolls in quarter-turns around its local X axis. State 1 turns its marked deck onto the vertical landing's gravity plane. The character's foot, normal, heading and orbit remain support-local throughout. Rotating before boarding disconnects the entrance; the player can recall the deck from architectural view.

| Carrier state | Available normal seam |
|---|---|
| 0 / entrance | Arrival - causeway - carrier |
| 1 / landing | Carrier - vertical landing |
| 2 or 3 / unjoined | Neither neighbour |

Ordinary walking cannot reach the carrier's other faces or bypass the rolling mechanism. The first boarding saves a checkpoint. Move far enough onto the deck to clear the joint before rotating.

### The Folded Landing

After rolling to state 1, continue along the same deck to the violet landing. Its authored path is on a vertical world plane. The camera frames it as the character's ground. There is no free wall-walking transition at this seam: the carrier has already brought the occupied path into the landing's plane.

Arrival at the landing saves another checkpoint. A short horizontal branch provides a safe place to stand while aligning the gallery. A conservative gallery sweep guard rejects turns when the player stands too close to it.

### The Joined Galleries

A ten-unit covered gallery starts sideways (state 1). From the safe landing, select it and rotate to state 0. Its corridor and a distant counterpart align in the composed architectural view. The central authored walking region opens only in this accepted arrangement.

Walk along the ivory paving into the corridor, through its far end, and toward the light. The spatial crossing is two-way; the player can walk back into the source gallery. There is no flash, teleport sound or crossing announcement.

## Impossible passage implementation and presentation

The source and destination share parallel local frames, translated by (-18, -15, -24). Both galleries have matching floors, walls, ceiling, ribs and inset lights. Deep entrance reveals, pilasters, recessed panels and a shallow pitched roof give them a consistent architectural profile. The landing and destination use compound support volumes: a compact landing, narrow gallery neck and destination terrace replace the oversized backing slabs. Selection, body and camera collision follow those volumes. The source floor and paving end at the hidden seam rather than projecting an extra slab over the destination. Gallery necks and the destination terrace have a shallow, consistent floor edge at the same support-local height. An open destination court contains a low beacon pedestal, exposing the goal and the approach beneath the traveller. The former roofed beacon chamber is retired. The seam is ten units inside the entrance, at support-local Z = -11, so the trailing camera is inside matching architecture when the body crosses.

A SubViewport renders the other endpoint using the same camera translation applied to traversal. A one-sided, unshaded aperture at the concealed end displays this view. The reverse aperture faces the opposite way; neither casts a shadow. This prevents the return surface from hiding the avatar or destination while the follow camera trails a recent crossing. Apertures are excluded from each other's render cameras to avoid recursion.

Crossing maps contact, local heading, local gravity and orbit together. The camera translates with the player. A small directional crossing margin avoids immediate retriggering. First-person pitch is preserved. The connection persists when switching to traversal; view direction does not activate arbitrary endpoints.

This is an authored parallel-frame pair, not a general impossible-space renderer. Arbitrary rotated pairs, recursive views, oblique clipping, broad exterior openings and perfect views from unrestricted angles remain future work. Tight orbit angles at gallery mouths still need playtesting. Enclosure and the composed sightline are deliberate presentation constraints.

## Layout

| Piece | World centre | Local dimensions | Orientation / path |
|---|---|---|---|
| Arrival | (-13, 0, 0) | (6, 2, 6) | UP; X from -2.8 to 3, Z +/-0.8 |
| Causeway | (-8, 0, 0) | (4, 2, 2) | UP; X +/-2, Z +/-0.8 |
| Carrier | (0, 0, 0) | (12, 2, 3) | Local UP; X +/-6, Z +/-0.8; rolls about X |
| Landing | (10, 0, 0) | (8, 2, 24) | X rotation 90 degrees; T-shaped authored path |
| Destination | (-8, -15, -24) | (6, 2, 32) | X rotation 90 degrees; central path to light |

Start is arrival-local (-1.8, 1, 0), facing local +X. The landing's horizontal path spans X -4 to 0.9, Z +/-0.8. Its central branch spans X +/-0.9 and extends to Z -11 only when the gallery is aligned; otherwise it ends at Z -1. The gallery pivots at (0, 1, -6) relative to the landing. The destination path ends at Z -15.5; the light is near Z -14.6.

## Manipulation, safety and recovery

Manipulation disables movement and settled neighbour links. The carrier's attached-body sweep is sampled at 24 intermediate angles against fixed architectural volumes. A stationary player can also block a turn that would sweep into them. Gallery rotation requires standing outside its conservative sweep zone. Rejected actions provide an explanation.

Undo restores both structure configuration and the player's complete local pose, even after disembarking. Checkpoints are saved at the start, boarding, landing and first distant arrival, never mid-animation. Returning to a checkpoint clears undo history. Save version 3 rejects coordinates from the retired free-surface layout. A workstation backup of the earlier save was made before migration; the source concept and previous Git revisions remain available.

No lives, time penalty, inventory, combat or economy are introduced. New journey resets the current local progress. Test mode does not load or write player progress.

## Interface, sound and accessibility

HUD shows current mode, chapter, objective, support and essential controls. The carrier panel distinguishes settled connectivity from actual occupancy. Contextual guidance is derived from the present support and configuration, including backtracking. It can be disabled in settings. Requested H hints escalate by current context and reset gently when that context changes.

Generated footsteps and tones communicate movement, turning, settling and completion. Essential feedback is also visible. There is deliberately no special sound at the concealed spatial seam. Rich ambience, material-specific sound and environmental narrative remain production work.

| Control | Default |
|---|---|
| Walk / orbit or first-person look | WASD / mouse |
| Switch architectural / traversal | Tab |
| Select carrier / turning gallery | 1 / 2, or click in overview |
| Turn | Q / E or buttons |
| Undo / checkpoint | Z / R |
| Hint / pause | H / Escape |

Movement, switching, turning, undo, recovery and hints can be rebound. Escape, mouse and 1/2 remain fixed in this prototype. Conflicting keyboard bindings swap. Settings persist locally, including contextual guidance, sensitivity, camera mode/distance, horizon and reduced motion.

## Art and production scope

Abstract, inhabitable architecture uses navy/violet atmosphere, terracotta machinery, muted teal destination and ivory paths. Warm highlights identify important details without an RGB axis code. All current geometry, materials and sound are generated locally. Production assets could add bevels, ceramic/stone/metal materials, restrained surface detail, richer lighting and narrative landmarks.

Implemented: authored rectangle paths; occupied gravity-changing roll; composed overview with ground-relative roll; one aligned two-way concealed passage; surface-following camera; collision checks; recovery; settings; guidance; completion. Explicit exclusions remain multiplayer, procedural campaign generation, combat, physics-object collection, unrestricted gravity changes and a complete campaign.

Next acceptance questions: does a player understand path boundaries, predict the roll, choose to board first, recognize gallery alignment, and experience the crossing as architectural continuity? Use [playtest.md](playtest.md). Technical checks and visual evidence are in [validation.md](validation.md).

## Implementation map

- `scripts/surface_piece.gd`: architecture, authored regions and settled neighbour references.
- `scripts/surface_walker.gd`: constrained movement, support-local pose, camera and solid checks.
- `scripts/game.gd`: authored layout, rotations, passage rendering/crossing, state, sound and integration checks.
- `scripts/hud.gd`: controls, guidance and settings.
- `scenes/main.tscn`: procedural scene entry point.

The original document retains all proposed world, narrative, campaign, art, interface and production ideas. This specification records the current interpretation and explicitly separates implemented features from that larger proposal.
