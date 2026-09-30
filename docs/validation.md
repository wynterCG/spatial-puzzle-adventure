# Revision 3 validation

30 September 2026. Godot 4.6.1, Compatibility/OpenGL, with the user's Godot MCP Pro 1.17.1. This revision replaces the prior automatic edge-wrapping and exposed arch prototype.

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
- The actual source/destination endpoints overlap in the fixed orthographic projection.
- Switching architectural/traversal views does not change the puzzle snapshot.
- Forward and reverse concealed crossings preserve support-relative contact, gravity, heading, orbit and first-person pitch.
- The return aperture faces away from the trailing arrival camera instead of occluding the avatar/goal.
- The route continues to the light and recovery preserves an accepted authored contact.
- First person hides the avatar; camera preferences do not mutate puzzle state.

The staged portable checkout is also tested without the proprietary addon or machine overrides. Test mode neither loads nor writes player progress.

## Live MCP Pro walkthrough

Walked the entrance path to the carrier through the actual walker, rolled the occupied deck using the animation action, reached the vertical landing, aligned the gallery, and walked through its concealed seam to the destination. Also walked back through the seam, returned to the destination and reached completion. Checked the default third-person view before/after crossing and the character's world-up change after the roll.

The visual pass found that a two-sided return aperture could obscure the character and destination after arrival. The aperture now faces the reverse direction, uses back-face culling, and casts no shadow. Inspected the corrected rendered result and added an orientation regression check.

The normal-play overview now has one composed angle. The previous inspect-separation control was removed after the user's clarification about camera-dependent illusions. Runtime screenshots below show the current architectural path and concealed passage; older images in this directory document retired iterations.

## Current screenshots

- [Authored path layout and fixed overview](authored-paths-overview.png)
- [Third person after rolling onto the landing's gravity plane](authored-paths-rolled-deck.png)
- [Aligned galleries in the composed view](joined-galleries-overview.png)
- [Interior immediately before crossing](gallery-before-crossing.png)
- [Interior immediately after crossing](gallery-after-crossing.png)

## Remaining evaluation

This is an instrumented technical walkthrough, not a first-time human playtest. Use [playtest.md](playtest.md) for route comprehension and comfort. The enclosed, parallel-frame portal pair has deliberate presentation constraints; arbitrary rotated endpoints, recursive rendering, oblique clipping and perfect views from every orbit angle are not claimed. See [spec.md](spec.md) for scope.

The prior local free-surface save was backed up before migration. Old save version 2 is not loaded into the new authored-path layout. Camera and control preferences remain compatible.
