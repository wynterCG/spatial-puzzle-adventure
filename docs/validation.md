# Revision 4 validation

30 September 2026. Godot 4.6.1, Compatibility/OpenGL, with the user's Godot MCP Pro 1.17.1. This update adds traversal interactions that persist into architectural view, plus an explicit rounded walkway to an underside control. Third person remains the default and first person remains available. The authored-boundary, gallery cutaway and consistent ground-relative camera rules are retained.

## Automated acceptance checks

The headless integration run must exit 0 and print SELF TEST PASS. Current checks cover:

- Local controls operate in third and first person and reject overview, remote, paused and completed-game use.
- The carrier brake rejects architectural rotation before its local release and permits it afterwards.
- Deployment disables links until settled; reduced motion applies it atomically. Undo and checkpoint recovery restore mechanism state, visible geometry and player contact together.
- Continuous screen-relative forward/backward walking reaches the underside via the ribbon and returns to the entrance. Follow-camera clearance is checked at distances 3, 5.5 and 8 with reduced motion both on and off.
- Curved contact normals change continuously; the full isometric frame stays constant relative to the local tangent frame. Ribbon sides and tail stop movement, and mid-curve snapshots restore in both camera modes.
- Version-3 authored-path progress migrates with carrier access preserved.
- Forbidden side/underside contact and blocked ordinary edges on ordinary supports, including diagonal approaches.
- A disconnected deck cannot be boarded across a gap.
- The real entrance path reaches the deck and creates the boarding checkpoint.
- An occupied quarter-roll changes world gravity while preserving the full local pose.
- Settling disables normal neighbour links.
- Follow camera framing through a full deck revolution at distances 3, 5.5 and 8, reduced motion on/off.
- The rolled deck joins the authored vertical landing.
- Undo after disembarking restores the configuration and passenger pose.
- An unaligned gallery blocks forward passage; an occupied sweep rejects rotation.
- The safe landing permits alignment.
- The landing/gallery view preserves source/destination endpoint projection alignment. Projected character-up remains screen-up.
- All eight directed occupied quarter-turns are sampled through their actual tweens. The camera retains exactly the same surface-local basis and remains above the ground, with finite transforms, throughout each turn and at settling. Reversing walking direction does not change the camera.
- Reduced motion changes geometry and camera together in a discrete turn; off-support turns leave its orientation alone.
- New journey resets the camera ground frame; recovery and undo retain the correct frame.
- Default full models, stable roof hover, hover exit, independent unaligned reveals, paired aligned reveals, interior occupancy and leaving for the goal court are checked.
- An unobstructed arrival needs no silhouette; the cutaway exposes the traveller without needing one inside the aligned gallery. Cutaway geometry is excluded only from overview, and both traversal and remote cameras include it.
- Compound volumes retain structural support and remove the obsolete slab collision.
- Switching architectural/traversal views does not change the puzzle snapshot.
- Forward and reverse concealed crossings preserve support-relative contact, gravity, heading, orbit and first-person pitch.
- The return aperture faces away from the trailing arrival camera instead of occluding the avatar/goal.
- The route continues to the light and recovery preserves an accepted authored contact.
- First person hides the avatar; camera preferences do not mutate puzzle state.

The staged portable checkout is also tested without the proprietary addon or machine overrides. Test mode neither loads nor writes player progress.

## Live MCP Pro walkthrough

For revision 4, operated the entrance lever through the interaction input handler and inspected the resulting deployment. Walked the rounded ribbon to its underside control, operated the brake release, returned along the same curve, boarded and rolled the carrier, reached the landing, aligned the gallery and crossed to Destination beyond local Z=-14. Inspected third-person interaction prompts, the full deployed curve in overview, the underside control and the overview after release. The character remains upright on screen relative to the new ground. MCP editor errors reported count 0. Player state and the existing checkpoint file were backed up before the walkthrough and restored afterwards.

Walked the entrance path to the carrier through the actual walker, rolled the occupied deck using the animation action, reached the vertical landing, aligned the gallery, and walked through its concealed seam to the destination. Also walked back through the seam, returned to the destination and reached completion. Checked the default third-person view before/after crossing and the character's world-up change after the roll.

The visual pass found that a two-sided return aperture could obscure the character and destination after arrival. The aperture now faces the reverse direction, uses back-face culling, and casts no shadow. Inspected the corrected rendered result and added an orientation regression check.

The camera now transports one fixed local frame with the occupied support, replacing the opposite-viewpoint selection and overhead side-switch arc. The local offset (36, 48, -30) preserves the previous landing view while keeping front/back azimuth and elevation consistent through all rotations. Gallery projection alignment is checked on the landing plane; it is not claimed for other gravity planes. Background-only monuments are kept behind the playable composition in overview to avoid obstructing the new viewing angles.

Modules remain complete by default. A gallery opens on hover or physical interior occupancy and closes when neither applies. The reveal uses stable full geometry bounds; aligned overlapping shells reveal together. Other visible obstructions can still trigger the silhouette fallback. Traversal and passage cameras retain the enclosure.

The gallery now has framed reveals, pilasters, recessed panels and a pitched roof. Compact compound volumes replace the oversized backing slabs. The beacon sits on a low pedestal in an open destination court. The former roofed chamber and deep overlapping end slab are removed; the source floor/paving now end at the seam. Shallow floor edges expose the continuation to the goal. Existing version-3 authored path coordinates remain compatible.

## Current screenshots

- [Third-person entrance control](rounded-track-control.png)
- [Extended ribbon in architectural view](rounded-track-overview.png)
- [Underside control reached by walking](rounded-track-underside.png)
- [Released mechanism and consistent underside overview](rounded-track-released.png)

The earlier camera/gallery captures below document the unchanged gallery behavior:

- [Complete modules with the character outside](module-full.png)
- [Gallery reveal selected by the roof hover ray](module-hover.png)
- [Occupied gallery with no hover](module-occupied.png)
- [Consistent camera on the landing orientation](consistent-camera-landing.png)
- [Same camera angle on the underside](consistent-camera-underside.png)
- [Same camera angle on the opposite orientation](consistent-camera-opposite.png)

Earlier images document previous iterations; they are not visual evidence for the rebuilt gallery.

## Prior Jev playtest

The optional runner in `tools/jev_playtest.mjs` uses TypeSafe's official decision API and Godot MCP Pro. Supply `TYPESAFE_API_KEY` and `GODOT_MCP_CLI` in the environment, run the game, then run `node tools/jev_playtest.mjs`. No SDK installation is needed. The runner pauses autonomous game processing, presents support-local state and a bounded set of controls, executes Jev's chosen actions through the actual walker/rotation functions, and restores runtime state and the checkpoint file in a finally block. Do not stop Godot during the run.

Jev receives structured route geometry and guidance, not screenshots. This measures state-based navigation, not visual believability, first-time puzzle discovery or human comfort. The runner filters controls unavailable in the active view and remembers actions blocked at an unchanged pose. Its movement inputs use support-local directions; this does not validate mouse or screen-relative input.

Before this visual correction, both live runs used `jev-1.13.0` and exhausted a 60-decision budget without completing the route. The [unfiltered trace](jev-playtest-unfiltered.json) reached the carrier, then repeated blocked northward movement and tried turns from traversal mode. The [filtered trace](jev-playtest-report.json) respected view availability but paced along the entrance/carrier path and did not choose the needed transformation. These are failed agent solves, not game acceptance passes. The deterministic route and camera suite passes separately. No claim of successful Jev completion or visual evaluation is made.

API contract: [TypeSafe official quickstart](https://docs.typesafe.ai/introduction/quickstart). The repository contains no API credentials or paid addon files. The runner now exposes nearby interactions and uses the surface tangent frame on the curved ribbon. Its JavaScript syntax was checked; no new Jev API solve was run for revision 4.

## Remaining evaluation

This is an instrumented technical walkthrough, not a first-time human playtest. Use [playtest.md](playtest.md) for route comprehension and comfort. The enclosed, parallel-frame portal pair has deliberate presentation constraints; arbitrary rotated endpoints, recursive rendering, oblique clipping and perfect views from every orbit angle are not claimed. See [spec.md](spec.md) for scope.

The prior local free-surface save was backed up before migration. Old save version 2 is not loaded into the authored-path layout. Version 3 is accepted with the new mechanism flags inferred from existing progress; new saves use version 4. Camera and control preferences remain compatible.
