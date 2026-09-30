# Elsewhere — game specification

Prototype specification, 30 September 2026. Working title, not a final product name.

The supplied [complete original concept](original-concept.md) is preserved verbatim. It is design input, not operational instructions. Its narrative, controls, chapter structure and production scope remain proposals. This document records every design area and identifies what the first playable build actually implements.

## 1. Identity and high concept

- Single-player spatial puzzle adventure, alternating first-person traversal with an isometric architectural view.
- Core fantasy: step outside an impossible world, reshape it, and return inside to experience the consequences.
- Walk across the tops, sides, undersides and eventually interiors of architecture. Gravity follows the supporting surface rather than universal down.
- Manipulate selected local structures through authored configurations. Remain attached to the same local position, heading and support face as the structure moves.
- Solve a sequence of configurations and choose where to stand before each change; simply arranging the whole puzzle then walking to the exit is insufficient.
- Architectural readability, Escher-like spatial contradictions and playful immersive abstraction are references, not assets to reproduce. The original mentions a Rose's Room reference image; that image was not supplied with this task.
- Identity: a calm, visually expressive journey. “From outside, reshape the world. From inside, discover how to cross it.”

## 2. Design pillars

1. **Transform outside, understand inside.** Both cameras inhabit the same world state. Overview reveals structure; first person reveals physical scale, local discoveries, openings and thickness.
2. **Movement is part of the solution.** Occupancy of a particular piece or face matters. Quiet traversal is welcome, but positioning must recur as a meaningful puzzle step.
3. **Impossible space, dependable rules.** Camera changes never invalidate accepted connections. Gravity requires surface continuity, never proximity or gaze.
4. **Wonder without visual noise.** Large readable masses first; detail, materials, lighting and sound enrich the architecture without obscuring its relationships.

## 3. World and narrative

The intended world is open in presentation and bounded in manipulation. Suspended courtyards, luminous towers, arches and distant destinations suggest one continuous environment. Only the local assembly is editable. Distant scenery remains context, a landmark or a later destination, physically separated from the traversal system.

Proposed story: spatial relationships have drifted out of alignment, although the architecture is intact and beautiful. Follow an illuminated landmark and reopen routes. Environmental storytelling and minimal dialogue are sufficient; combat, inventory and a large cast are unnecessary. No universal final arrangement repairs the entire world: temporary arrangements form a journey.

**Prototype:** one courtyard and a separate illuminated destination, surrounded by non-traversable distant silhouettes. No dialogue or narrative production assets.

## 4. Camera modes

### First person

Walk, look, explore and position the character. There is no required jumping, precision platforming, combat, time limit or gravity-launch action. Scale and local discoveries must be legible.

### Architectural view

Walking pauses. An orthographic camera frames the assembly; select the carrier or arch, then use quarter-turns. The character stays visible at its actual support contact, with a small luminous contact ring. Consult this view on demand with no resource, station or cooldown.

The current build offers upper and lower inspection views, toggled with F or a visible button. Entering architectural mode automatically chooses the lower view when the player's world up points down. Inspection cannot change piece states or create a connection. Perspective-dependent connections remain authored state rules; camera movement never generates arbitrary connections.

### Transitions and comfort

The prototype interpolates a temporary perspective camera between inhabitant and architect poses over 0.45 seconds, then uses the destination camera's projection. The projection handoff is a prototype compromise. Reduced motion uses an immediate cut and shortens structural rotations. Edge reorientation normally smooths over a short interval; reduced motion snaps to the new frame. Neither approach is assumed universally comfortable: playtesting remains necessary. No head bob is enabled.

## 5. Surface-relative traversal

### Governing rules

- All six continuous faces of each designated cuboid are walkable, including undersides.
- Traverse an exterior edge by continuing to walk. Fold the remaining movement onto the adjoining face and rotate heading and local up together.
- Transfer between different pieces only when their settled surfaces physically meet on a matching plane.
- Never attract the player across gaps, to nearby scenery or toward a looked-at surface.
- Multi-face corner ties use deterministic X/Y/Z axis priority.
- Colour communicates atmosphere and object identity, never X/Y/Z axes.

**Implementation:** deterministic analytical surface constraint in `SurfaceWalker`, with small movement substeps. Store support, local contact point, normal and heading. Godot physics is used for click selection, not gravity simulation.

Body probes prevent entry into adjacent solid volumes at the stepped joins. Shared internal faces are not exposed walking surfaces. Edge events fire after both the contact position and orientation are committed, so a checkpoint cannot capture a partially updated pose.

**Future:** concave interior corners need intentional forward transition tests; arbitrary meshes and curved surfaces are not implemented. The prototype has convex cuboids and aligned seams only. Decorative arch trim and distant structures are not support surfaces. Solid collision for decorative arch posts is still a production limitation.

## 6. Structural manipulation and attachment

The carrier rotates in 90-degree yaw steps about its centre. A spindle and warm selection edges indicate the movable piece. A local coordinate frame makes the character move naturally with any support transformation, including when standing on side faces. Fixed platforms preserve spatial reference.

Movement and passage crossing are blocked during animations; only settled states create usable connections. Rotations keep the architectural camera stable. The prototype samples the attached body at 24 intermediate angles against fixed volumes, rejecting unsafe sweeps with visible feedback. Turning the arch is refused while the player stands in its sweep region. This is conservative blockout validation, not general swept-mesh collision detection.

## 7. Three spatial behaviours

| Behaviour | Rule | Prototype |
|---|---|---|
| Continuous geometry | A real path around sides/undersides | All six cuboid faces; hidden underside inscription |
| Physical reconfiguration | Rotate until surfaces genuinely meet | Carrier alternates start and courtyard adjacency |
| Impossible connection | Authored endpoints become neighbours while separated | Settled arch state 0 opens a passage to the distant volume |

The arch's accepted configuration activates the connection independently of camera mode. It remains active until a structural change invalidates it. A SubViewport renders the destination through a framed opening; a screen-space material displays that view on the aperture. The destination camera is translated by the same coordinate mapping used for crossing. Foot position and heading persist; local up remains consistent because the initial pair has parallel upright frames.

**Prototype limits:** one forward passage, one endpoint pairing, parallel frames and no recursive portal rendering. Returning through the destination is not implemented; checkpoint recovery and undo remain available. Arbitrary portal rotation, two-way paired openings, oblique clip planes and convincing views from every angle are future work. The overview is a readable state inspection, not yet a finely composed forced-perspective illusion. No accidental screen overlap creates connectivity.

## 8. Puzzle state and core loop

State comprises piece configurations, active connections and the player's support, face, local position and orientation. The loop is:

**Observe → reconfigure → enter → reposition → reconfigure again → traverse → discover.**

A transformation may close the previous route while opening the next. Seeing the goal establishes intent, not the solution. Constraints must arise from real gaps, disconnected volumes, incompatible states and occupancy. A start and exit on different faces of a single unrestricted solid is not a valid route puzzle. Optional branches should provide understanding, vistas or discoveries rather than arbitrary dead ends.

## 9. Puzzle sequence and current layout

### The Other Ground

Full concept: a useful underside passage on a connected arm leads across to a separate arrival platform. Teach that walls and ceilings are ground without impossible connectivity.

**Implemented opening:** the tall arrival slab is separated from the carrier by a narrow fixed causeway. Their top heights and side widths differ; the only matching walking plane at both joins is the underside at world y=-1. Walk around an exposed near/far edge of the arrival, down its wall and underneath it. Turn toward the causeway, cross below it, and board the carrier in state A. Ribs, inset lights and wall recesses make the architecture readable without an automatic solution line.

Progress flags report discovery and update hints; they do not unlock movement. Boarding is constrained by the surface geometry and matching-plane seam rule. Collision probes prevent walking through the solid shared joins. General concave corner climbing is still outside this walker; the level must be reevaluated for alternate routes when that capability is added.

The first carrier boarding saves a checkpoint and advances the chapter from The Other Ground to The Passenger. Rotating the carrier before boarding disconnects its underside from the causeway. The lower inspection view makes the contact and character visible.

### The Passenger

| Carrier orientation | Connection |
|---|---|
| A: 0° / 180° | Arrival underside ↔ causeway underside ↔ carrier underside |
| B: 90° / 270° | Carrier ↔ courtyard |

Rotating to B from the start removes access to the carrier. Board in A, rotate while aboard, then walk off in B. The new opening naturally delivers the player to the courtyard underside; wrap around an exposed courtyard edge to reach the arch on top. A later version should require repositioning onto a particular side-face exit before rotation.

### The Distant Arch

Reach the courtyard, stand clear of the arch, select it and rotate from its initial 90° state to 0°. The opening becomes visibly connected. Enter in first person to reach the distant destination, then approach the light to finish. A later combination should make entry and departure alignments mutually exclusive so boarding matters here too.

### The Return Route

Future combination: an apparently nearby goal occupies a separate disconnected volume. Travel away through several assemblies, reach an interior passage and return from an unexpected direction. Preserve the goal landmark so the surprise arises from understanding adjacency, never secretly relocating the goal.

### Blockout dimensions

| Piece | Centre | Dimensions |
|---|---|---|
| Arrival | (-16, 2, 0) | (8, 6, 8) |
| Causeway | (-9, 0.4, 0) | (6, 2.8, 2.2) |
| Carrier | (0, 0, 0) | (12, 2, 3) |
| Courtyard | (0, 0, -10) | (7, 2, 8) |
| Destination | (19, 0, -22) | (8, 2, 10) |

Arrival top is y=5; causeway top is y=1.8; carrier and courtyard tops are y=1. All undersides share y=-1. The player starts at arrival-local (-1, 3, 1), facing its exposed +Z edge. Source aperture is at (0, 1, -11.6); the crossing maps to the destination by (19, 0, -10), with a small forward crossing margin. The destination goal is near z=-25.5. Test every face when changing these values.

## 10. Campaign progression

Hand-authored connected regions combine a small, consistent rule set:

1. Arrival spaces: surface transitions, cameras, landmarks.
2. Moving courtyards: attachment, rotations, mutually exclusive paths.
3. Linked chambers: impossible connections, composed views, interior/exterior relationships.
4. Larger compositions: multiple pieces, occupancy and return journeys.
5. Finale: ambitious use of established rules, no unexplained new exception.

Completion means reaching destinations, not accumulating currency or time ratings. Optional content can offer vistas, discoveries and extra puzzles. Only the first compact courtyard exists in this build.

## 11. Art direction

Abstract but inhabitable architecture with clear silhouettes, negative space and consistent thickness. Deep navy/violet foundations, ivory light, terracotta/amber accents and a muted teal destination establish object identity without axis coding. The prototype uses procedural cuboids, subtle corner seams, inlays, framed openings, celestial points and layered distant towers.

Production materials may include painted panels, glazed ceramic, smooth stone, brushed metal, translucent inserts and recessed light strips. Add bevels, roughness detail and contact shadows selectively. Luminous borders should emphasize interactions rather than outline everything equally. Different regions can vary palettes while sharing a coherent shape language. Asymmetric landmarks should remain recognizable when gravity changes.

No external art, fonts, textures or sound packs are needed for the prototype.

## 12. Audio, interface and controls

The current build generates small tonal cues for footsteps, transformations, settled connections and completion. Every essential audio event also has visible feedback. Future audio should distinguish open/enclosed environments and materials, with joint engagement, sliding and settling sounds. Quiet ambience and a restrained soundtrack should leave room for observation.

The interface shows mode, current support, objective, selected structure and essential controls. No axis legend, automatic solution line, economy or full-screen schematic.

| Action | Default |
|---|---|
| Walk / look | WASD / mouse |
| Change perspective | Tab |
| Inspect upper / lower faces | F in architectural view |
| Select movable structure | Left click in overview |
| Select carrier / arch | 1 / 2 |
| Quarter-turn left / right | Q / E, or visible buttons |
| Undo settled transformation | Z |
| Return to checkpoint | R |
| Escalating hint | H |
| Pause / settings | Escape |

Movement, perspective, inspection, rotation, undo, recovery and hint keys can be remapped in settings. Conflicting bindings swap rather than silently disable another action. Mouse look/click, Escape and the 1/2 shortcuts are fixed in this first build. Settings persist locally.

## 13. Experimentation, recovery and comfort

- Undo restores the pre-transformation configuration **and** player pose, not just reverse rotation under a relocated player.
- Checkpoints at entry, first carrier boarding, courtyard and destination restore stable states. Never save mid-rotation or mid-crossing. Save schema version 2 rejects earlier-layout checkpoints without loading them into invalid geometry; settings are preserved.
- `user://journey.save` stores checkpoint progress. `user://settings.cfg` stores key bindings, sensitivity and reduced motion.
- No lives, time penalty or punitive loss of campaign progress.
- Adjustable sensitivity, reduced-motion transitions and no default head bob.
- Hints escalate from a relevant relationship to a concrete action; no automatic full-route overlay.
- “Start a new journey” resets this local prototype's progress. Returning to a checkpoint clears transformation history.

## 14. Prototype scope, acceptance and next work

### Implemented

- Runnable Godot 4.6 project and single continuous courtyard.
- First-person and orthographic architectural views.
- Six-face cuboid traversal, edge reorientation and physical seams.
- Mandatory underside causeway opening, solid-join body checks and upper/lower inspection views.
- Quarter-turn carrier, local attachment and state-dependent adjacency.
- Selectable arch with one persistent impossible passage and destination preview.
- Undo, checkpoints, progress persistence, completion and restart.
- Scalable HUD, click selection, hints, pause, sensitivity, partial input remapping and reduced motion.
- Procedural art and generated sound; Godot MCP Pro 1.17.1 addon enabled.

### Explicit exclusions

Multiplayer, procedural puzzle generation, combat, physics-object collection, unrestricted gravity jumping, inventory, time ratings and a full campaign. The local MCP addon is a development dependency, not gameplay logic.

### Acceptance questions

Can a player predict the result of a rotation? Can they identify their location and support afterward? Does occupancy change the solution? Does the impossible connection remain understandable in first person? Does free exploration of sides and undersides expose a bypass? Does the contact marker remain legible? Are corners predictable and camera transitions comfortable?

### Remaining production work

Concave and multi-piece inner corners (with a fresh route audit); solid arch collision; bidirectional, arbitrarily oriented paired passages; polished portal clipping and forced-perspective composition; expanded safe-sweep checks for future assemblies; fully remappable mouse and system controls; controller support; additional regions; richer environmental narrative, materials and audio; accessibility/playtest iteration.

The success criterion is a player making a spatial prediction, testing it with a transformation and walking through the result—not camera-induced confusion.

## Implementation map and engine references

- `scripts/game.gd`: scene construction, configurations, connections, cameras, recovery, audio and integration smoke tests.
- `scripts/surface_piece.gd`: traversable cuboid, selection collision and materials.
- `scripts/surface_walker.gd`: support-local movement and edge folding.
- `scripts/hud.gd`: interface, settings and rebinding.
- `scenes/main.tscn`: main scene entry point.
- [Godot Viewport documentation](https://docs.godotengine.org/en/stable/classes/class_viewport.html): the SubViewport shares the game's World3D for destination rendering.
- [Godot environment documentation](https://docs.godotengine.org/en/4.5/tutorials/3d/environment_and_post_processing.html): environment and light configuration reference.
