# Optional gallery experiment ? revision 4 reference

This records the earlier guided level. The current positioning studies are specified in [spec.md](spec.md). The latest world-aligned third-person camera preference also applies to this experiment.

# Elsewhere - current game specification

Prototype revision 4, 30 September 2026. Working title.

## Authoritative design corrections

The user's clarifications supersede conflicting passages in the [original concept](original-concept.md), which remains preserved in full:

1. Third person is the default traversal view for comfort; first person is optional.
2. Movement follows **authored walkable paths**. Ordinary edges stop movement. The character cannot freely walk onto every face of a solid.
3. A moving support carries the player's local position, heading and gravity. Changing orientation requires a designed mechanism or transition; the current opening combines an authored rounded walkway and an occupied rolling deck.
4. The architectural view is fixed relative to the occupied walking surface: the same azimuth, elevation and distance throughout rotations. It stays above the floor without switching between front and back views. A freely orbiting overview would expose view-dependent illusions. The former separation/underside inspection control has been removed from normal play.
5. **Portal describes the spatial technique, not the visual theme.** A pair of separated endpoints becomes directly traversable through ordinary-looking architecture. The accepted arrangement activates the connection; the camera does not sustain it.

The old unrestricted edge wrapping remains retired. The latest addition deliberately reintroduces an underside route through a visibly rounded, authored ribbon. Local interactions work in third person, with first person retained as an optional setting; their changes persist into architectural view.

## Identity and design pillars

Single-player, calm architectural puzzle adventure. Alternate between being an inhabitant and an architect. Observe, reconfigure, enter, reposition, reconfigure again, traverse and discover. Occupancy and sequencing matter: arranging the exit before boarding can remove access to the moving support.

Both views show the same world state. Rules must be predictable even when adjacency is impossible. Use architectural landmarks, clear routes and atmosphere. No axis-colour legend, default full-route overlay, required jumping, combat, precision platforming or time pressure.

## World, story and campaign

Suspended structures, distant light and intact architecture suggest a world whose relationships have drifted out of alignment. Temporary arrangements form a journey; there is no universal repaired configuration. Environmental storytelling is preferred over dialogue or inventory systems.

The intended campaign progresses through arrival spaces, moving courtyards, linked chambers and larger combinations. A later return route can revisit a visible landmark from an unexpected direction. Optional branches should reveal useful relationships or additional puzzles. These campaign regions remain proposed; only the compact opening below exists.

## Traversal and path boundaries

Flat supports define one or more rectangles in their local X/Z plane at local Y = half-height. Only this authored local-UP face is walkable. The rounded walkway is a separate analytic ribbon with a changing surface normal. Ivory paving communicates the regions; unused architectural mass is not a walking route.

Movement uses short substeps and constrains attempted movement to the region union. A path edge stops the character without changing their normal or dropping them into the void. No automatic face folding, nearest-object gravity, gap snapping or camera-dependent attachment is allowed. Footstep feedback is based on actual movement, not blocked input.

A normal cross-piece seam requires both an authored neighbour relationship and genuinely touching compatible walking regions. Links exist only in accepted settled states. Geometry and body checks also reject entry into solid architecture. Merely touching an unmarked side does not create a path.

The rounded walkway is an explicit gravity transition: a radius-3 half-circle followed by a 3-unit underside landing, with walkable half-width 0.8. Contact uses distance along the curve and lateral position. Gravity, walking heading and orbit are transported together through its tangent frame, so continuing forward carries the traveller from upright through a wall orientation to upside down. Returning reverses the same curve. Side edges and the far end stop movement. Rendered articulated slats follow the same analytic route, with box solids for camera/body clearance. This is one authored convex curve, not arbitrary mesh navigation, nearest-surface gravity or permission to wrap around other edges. Stairs, concave curves and general spline authoring remain future work.

## Cameras and comfort

Traversal defaults to a visible third-person traveller. The camera orbit lives in the support frame and follows its rotation. New movement is screen-relative; mouse motion reestablishes the screen-relative heading. The follow frame eases into changes while obstruction checks prevent it from entering the main solids and gallery walls/roofs. A clear alternative on the settled surface is used when the interpolated arm becomes severely obstructed.

Follow distance is adjustable from 3 to 8 (default 5.5). Settings include sensitivity, reduced motion, optional fixed world horizon and optional first person. No head bob or camera shake is enabled. First person hides the avatar from its own camera. Camera settings are independent of puzzle checkpoints.

The orthographic architectural camera focuses on (-1, -2, -7), with size 46. Its offset is the occupied support's basis multiplied by the contact's surface frame and local vector (36, 48, -30). Its up direction uses the same ground frame. Flat supports use the identity contact frame; the rounded track rotates it continuously around the curve. This preserves one local azimuth, elevation and distance through every occupied rotation; it does not choose between opposite world-space viewpoints or react to the traveller's walking heading. The structure tween transports the camera frame continuously. Off-support turns leave it unchanged; reduced motion applies structure and camera together in a discrete turn.

The local offset is calibrated to preserve the existing world offset (36, 30, 48) on the landing/gallery plane. Thus the actual gallery endpoints still coincide in projection in the view used to align and traverse them. Views from the entrance and disconnected carrier orientations can expose their spatial separation; the concealed traversable connection remains configuration-driven and independent of camera mode. Decorative background monuments are culled from overview when they would stand in front of the playable composition, preventing foreground obstruction and camera clipping at the new angles. Traversal retains the full scenery. There is no arbitrary inspection orbit. Undo, checkpoint recovery, view switching and a new journey recover the camera from the restored support frame.


Architecture is complete by default in isometric view. Hovering a gallery or standing inside its interior reveals its roof and camera-facing wall as a cutaway, including removal of their shadows. Moving the pointer away closes it unless occupancy keeps it open. Leaving for the landing or goal court restores the full module. Hover uses the complete module volume even when the roof is hidden, preventing flicker; foreground support geometry and UI panels block hover. Hover is disabled during manipulation, pause and completion. Occupancy is tested in the module's local interior and requires the matching support, not merely a projected overlap.

Aligned galleries form one apparent passage and reveal together, so the duplicate shell cannot cover the opened interior. Unaligned galleries respond independently. Traversal and passage-render cameras always include the complete enclosure, regardless of hover or occupancy. Revealed walls/roofs use render layer bit 16, excluded only from overview. The opposite wall retains the corridor shape. A warm traveller silhouette on bit 8 remains a fallback for other visible structural obstructions and is excluded from traversal and remote views. Camera position alone does not guarantee visibility through masonry.


Walking pauses during architectural manipulation. Third-person view switches are cuts; optional first person retains its short transition unless reduced motion is enabled. Comfort still requires human testing.

## Current puzzle: extend, release, board, roll, align, cross

### The Rounded Walkway

The entrance has a short ivory branch leading to a rolled-up walkway and a brass lever. Enter traversal view, approach within 2 units and press the remappable interaction key (default F). A visible prompt appears for a reachable, unused control. Both third and first person work. Controls cannot be operated from overview, remotely, while paused, during a transformation or after completion. Reach requires the matching support, compatible ground orientation and a clear hand-height line through the mechanism/gallery obstacles.

The first lever extends the articulated ribbon over 1.2 seconds; its gate opens and its entry link activates only after it settles. Walk around the rounded edge onto the underside landing. A second brass lever releases the visible carrier brake. The release persists when changing views: the carrier can now rotate in isometric mode. Retrace the ribbon, board the carrier, and continue the existing puzzle. The gate, handle positions, brake and ivory route communicate the changes physically. Used controls remain in their operated positions. Undo can reverse either action and restores the character along with it.

Reduced motion applies each mechanism change in one settled step. The curved route still turns gravity as the character walks; disabling mechanism animation does not remove the necessary surface-relative camera rotation. Motion comfort remains a human playtest question. These mechanisms are a compact prototype of inhabitant actions enabling architectural changes, not an inventory or generic interaction system.

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

The source and destination share parallel local frames, translated by (-18, -15, -24). Both galleries have matching floors, walls, ceiling, ribs and inset lights. Deep entrance reveals, pilasters, recessed panels and a shallow pitched roof give them a consistent architectural profile. The source landing is a compact fixed volume. Its gallery floor, paving, walls and cover share the gallery pivot and rotate together; no duplicate fixed neck or trim remains beneath the turning module. The floor slab participates in body and camera collision and remains visible during cutaways. The destination retains its fixed neck and open terrace. These shallow floor edges share the same support-local height, and the authored source path ends at the hidden seam. An open destination court contains a low beacon pedestal, exposing the goal and the approach beneath the traveller. The former roofed beacon chamber is retired. The seam is ten units inside the entrance, at support-local Z = -11, so the trailing camera is inside matching architecture when the body crosses.

A SubViewport renders the other endpoint using the same camera translation applied to traversal. A one-sided, unshaded aperture at the concealed end displays this view. The reverse aperture faces the opposite way; neither casts a shadow. This prevents the return surface from hiding the avatar or destination while the follow camera trails a recent crossing. Apertures are excluded from each other's render cameras to avoid recursion.

Crossing maps contact, local heading, local gravity and orbit together. The camera translates with the player. A small directional crossing margin avoids immediate retriggering. First-person pitch is preserved. The connection persists when switching to traversal; view direction does not activate arbitrary endpoints.

This is an authored parallel-frame pair, not a general impossible-space renderer. Arbitrary rotated pairs, recursive views, oblique clipping, broad exterior openings and perfect views from unrestricted angles remain future work. Tight orbit angles at gallery mouths still need playtesting. Enclosure and the composed sightline are deliberate presentation constraints.

## Layout

| Piece | World centre | Local dimensions | Orientation / path |
|---|---|---|---|
| Arrival | (-13, 0, 0) | (6, 2, 6) | UP; X from -2.8 to 3, Z +/-0.8, plus branch X -2.6 to -1.0, Z -3 to 0 |
| Rounded walkway | (-14.8, 1, -3), entry | Radius 3; arc length 3*pi plus tail 3; width 1.6 | Curves about local X to DOWN; returns to Arrival at its upper end |
| Causeway | (-8, 0, 0) | (4, 2, 2) | UP; X +/-2, Z +/-0.8 |
| Carrier | (0, 0, 0) | (12, 2, 3) | Local UP; X +/-6, Z +/-0.8; rolls about X |
| Landing | (10, 0, 0) | (8, 2, 24) | X rotation 90 degrees; T-shaped authored path |
| Destination | (-8, -15, -24) | (6, 2, 32) | X rotation 90 degrees; central path to light |

Start is arrival-local (-1.8, 1, 0), facing local +X. The landing's horizontal path spans X -4 to 0.9, Z +/-0.8. Its central branch spans X +/-0.9 and extends to Z -11 only when the gallery is aligned; otherwise it ends at Z -1. The gallery pivots at (0, 1, -6) relative to the landing. The destination path ends at Z -15.5; the light is near Z -14.6.

## Manipulation, safety and recovery

Manipulation disables movement and settled neighbour links. The carrier's attached-body sweep is sampled at 24 intermediate angles against fixed architectural volumes. A stationary player can also block a turn that would sweep into them. Gallery rotation requires standing outside its conservative sweep zone. Rejected actions provide an explanation.

Undo restores both structure configuration and the player's complete local pose, even after disembarking. Checkpoints are saved at the start, each settled local interaction, boarding, landing and first distant arrival, never mid-animation. Returning to a checkpoint clears undo history. Save version 4 stores walkway deployment and brake release with the player pose. Version-3 authored-path saves migrate in memory: existing carrier/landing/destination progress retains access with the new mechanisms released; an untouched entrance starts with them closed. Older free-surface saves remain incompatible. A workstation backup was made before this revision; the source concept and previous Git revisions remain available.

No lives, time penalty, inventory, combat or economy are introduced. New journey resets the current local progress. Test mode does not load or write player progress.

## Interface, sound and accessibility

HUD shows current mode, chapter, objective, support and essential controls. The carrier panel distinguishes settled connectivity from actual occupancy. Contextual guidance is derived from the present support and configuration, including backtracking. It can be disabled in settings. Requested H hints escalate by current context and reset gently when that context changes.

Generated footsteps and tones communicate movement, turning, settling and completion. Essential feedback is also visible. There is deliberately no special sound at the concealed spatial seam. Rich ambience, material-specific sound and environmental narrative remain production work.

| Control | Default |
|---|---|
| Walk / orbit or first-person look | WASD / mouse |
| Switch architectural / traversal | Tab |
| Select carrier / turning gallery | 1 / 2, or click in overview |
| Local interaction in traversal | F near a control |
| Turn | Q / E or buttons |
| Undo / checkpoint | Z / R |
| Hint / pause | H / Escape |

Movement, switching, interaction, turning, undo, recovery and hints can be rebound. Escape, mouse and 1/2 remain fixed in this prototype. Conflicting keyboard bindings swap. Settings persist locally, including contextual guidance, sensitivity, camera mode/distance, horizon and reduced motion.

## Art and production scope

Abstract, inhabitable architecture uses navy/violet atmosphere, terracotta machinery, muted teal destination and ivory paths. Warm highlights identify important details without an RGB axis code. All current geometry, materials and sound are generated locally. Production assets could add bevels, ceramic/stone/metal materials, restrained surface detail, richer lighting and narrative landmarks.

Implemented: third/first-person local interactions; retractable curved ribbon to an underside control; persistent carrier brake release; authored rectangle paths; occupied gravity-changing roll; composed overview with ground-relative roll; one aligned two-way concealed passage; surface-following camera; collision checks; recovery; settings; guidance; completion. Explicit exclusions remain multiplayer, procedural campaign generation, combat, physics-object collection, unrestricted gravity changes and a complete campaign.

Next acceptance questions: does a player understand path boundaries, predict the roll, choose to board first, recognize gallery alignment, and experience the crossing as architectural continuity? Use [playtest.md](playtest.md). Technical checks and visual evidence are in [validation.md](validation.md).

## Implementation map

- `scripts/surface_piece.gd`: architecture, authored regions and settled neighbour references.
- `scripts/curved_track.gd`: analytic rounded contact, tangent frame, slat geometry and deployment.
- `scripts/surface_walker.gd`: constrained movement, support-local pose, camera and solid checks.
- `scripts/game.gd`: authored layout, rotations, passage rendering/crossing, state, sound and integration checks.
- `scripts/hud.gd`: controls, guidance and settings.
- `scenes/main.tscn`: procedural scene entry point.

The original document retains all proposed world, narrative, campaign, art, interface and production ideas. This specification records the current interpretation and explicitly separates implemented features from that larger proposal.
