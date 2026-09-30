# Revision 3 validation

30 September 2026. Godot 4.6.1, Compatibility/OpenGL, with the user's Godot MCP Pro 1.17.1. This revision replaces the prior automatic edge-wrapping and exposed arch prototype. The current update adds occupied-ground camera roll, an overview occlusion silhouette and a rebuilt gallery silhouette/supporting mass.

## Automated acceptance checks

The headless integration run must exit 0 and print SELF TEST PASS. Current checks cover:

- Forbidden side/underside contact and blocked ordinary edges, including diagonal approaches.
- A disconnected deck cannot be boarded across a gap.
- The real entrance path reaches the deck and creates the boarding checkpoint.
- An occupied quarter-roll changes world gravity while preserving the full local pose.
- Settling disables normal neighbour links.
- Follow camera framing through a full deck revolution at distances 3, 5.5 and 8, reduced motion on/off.
- The rolled deck joins the authored vertical landing.
- Undo after disembarking restores the configuration and passenger pose.
- An unaligned gallery blocks forward passage; an occupied sweep rejects rotation.
- The safe landing permits alignment.
- The actual source/destination endpoints overlap through a full revolution of the ground-relative orthographic frame. Projected character-up remains screen-up.
- Reduced motion holds the camera during the turn and cuts at settling; off-support turns leave its orientation alone.
- New journey resets the camera ground frame; recovery and undo retain the correct frame.
- An unobstructed arrival needs no silhouette; a covered gallery shows one in overview only.
- Compound volumes retain structural support and remove the obsolete slab collision.
- Switching architectural/traversal views does not change the puzzle snapshot.
- Forward and reverse concealed crossings preserve support-relative contact, gravity, heading, orbit and first-person pitch.
- The return aperture faces away from the trailing arrival camera instead of occluding the avatar/goal.
- The route continues to the light and recovery preserves an accepted authored contact.
- First person hides the avatar; camera preferences do not mutate puzzle state.

The staged portable checkout is also tested without the proprietary addon or machine overrides. Test mode neither loads nor writes player progress.

## Live MCP Pro walkthrough

Walked the entrance path to the carrier through the actual walker, rolled the occupied deck using the animation action, reached the vertical landing, aligned the gallery, and walked through its concealed seam to the destination. Also walked back through the seam, returned to the destination and reached completion. Checked the default third-person view before/after crossing and the character's world-up change after the roll.

The visual pass found that a two-sided return aperture could obscure the character and destination after arrival. The aperture now faces the reverse direction, uses back-face culling, and casts no shadow. Inspected the corrected rendered result and added an orientation regression check.

The camera now rolls about the composed sightline with the occupied ground. This keeps the parallel endpoint projections aligned while making the traveller upright on screen. Covered architecture remains opaque; the traveller receives a warm silhouette when structural geometry hides their head or torso. Inspected that silhouette inside the gallery through MCP Pro.

The gallery now has framed reveals, pilasters, recessed panels and a pitched roof. Compact compound volumes replace the oversized backing slabs. The beacon sits in a roofed chamber. Existing version-3 authored path coordinates remain compatible.

## Current screenshots

- [Ground-relative overview with traveller visible inside the gallery](overview-hidden-traveller.png)
- [Arrival frame before the occupied turn](overview-ground-before.png)
- [Occupied frame after the turn](overview-ground-after.png)
- [Rebuilt gallery interior near the concealed seam](rebuilt-gallery-interior.png)

Earlier images document previous iterations; they are not visual evidence for the rebuilt gallery.

## Jev playtest

The optional runner in `tools/jev_playtest.mjs` uses TypeSafe's official decision API and Godot MCP Pro. Supply `TYPESAFE_API_KEY` and `GODOT_MCP_CLI` in the environment, run the game, then run `node tools/jev_playtest.mjs`. No SDK installation is needed. The runner pauses autonomous game processing, presents support-local state and a bounded set of controls, executes Jev's chosen actions through the actual walker/rotation functions, and restores runtime state and the checkpoint file in a finally block. Do not stop Godot during the run.

Jev receives structured route geometry and guidance, not screenshots. This measures state-based navigation, not visual believability, first-time puzzle discovery or human comfort. The runner filters controls unavailable in the active view and remembers actions blocked at an unchanged pose. Its movement inputs use support-local directions; this does not validate mouse or screen-relative input.

Both live runs used `jev-1.13.0` and exhausted a 60-decision budget without completing the route. The [unfiltered trace](jev-playtest-unfiltered.json) reached the carrier, then repeated blocked northward movement and tried turns from traversal mode. The [filtered trace](jev-playtest-report.json) respected view availability but paced along the entrance/carrier path and did not choose the needed transformation. These are failed agent solves, not game acceptance passes. The deterministic route and camera suite passes separately. No claim of successful Jev completion or visual evaluation is made.

API contract: [TypeSafe official quickstart](https://docs.typesafe.ai/introduction/quickstart). The repository contains no API credentials or paid addon files.

## Remaining evaluation

This is an instrumented technical walkthrough, not a first-time human playtest. Use [playtest.md](playtest.md) for route comprehension and comfort. The enclosed, parallel-frame portal pair has deliberate presentation constraints; arbitrary rotated endpoints, recursive rendering, oblique clipping and perfect views from every orbit angle are not claimed. See [spec.md](spec.md) for scope.

The prior local free-surface save was backed up before migration. Old save version 2 is not loaded into the new authored-path layout. Camera and control preferences remain compatible.
