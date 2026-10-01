# Isometric camera experiment

Branch: `experiment/isometric-camera-adjustments`. The [user's proposal](isometric-camera-proposal.md) remains the design reference. First person remains the primary traversal camera. This experiment applies to the three positioning studies; the optional gallery keeps its calibrated overview.

## Decision

The user selected **B**, saying **"it reads way better"**, after playing the comparison. Ground-direction transport is now the standard in the three positioning studies. The A/B selector, stored mode preference and A runtime path are retired. Manual orbit, zoom and reset remain available. This is evidence of the user's preference, not a claim of validated comfort or comprehension for all players.

## Historical A/B behavior (commit `6e85e85`)

Both comparison modes retained the puzzle's fixed centre, full player attachment, surface-relative elevation, curve continuity, seam continuity, and independence from character facing and first-person look.

- **A — Follow the whole structure:** preserves the earlier full-support rotation behavior.
- **B — Follow the ground direction:** transports the previous overview reference through the shortest change in the occupied ground normal. Rotation about an unchanged normal adds no camera yaw. This was the comparison default and is now the selected behavior.

The comparison build offered A/B in Escape settings without changing camera framing, persisted the choice separately from snapshots, and disabled switching mid-turn. Current builds ignore that retired preference and remove it on the next preference save. A sudden exactly antipodal normal, which has no unique shortest axis, uses the previous reference's right axis; ordinary quarter-turn animations and walking around curves update continuously.

## Historical comparison before manual orbit

The initial automatic-camera implementation was checked mechanically and rendered through Godot MCP Pro before manual orbit was added. Both variants used the same passenger positions and carrier transformations, with recommended framing.

| Fixture | A camera rotation | B camera rotation | Player attachment |
|---|---:|---:|---|
| Study 2: occupied carrier turns 90 degrees about vertical | 90 degrees | 0 degrees | Full carrier transformation in both |
| Study 1: occupied carrier tilts 90 degrees | 90 degrees | 90 degrees | Full carrier transformation in both |
| Another structure turns while player stands on fixed ground | 0 degrees | 0 degrees | Fixed support retained |

The animated checks sample every 1/60 second, checking the normal and passenger transform throughout the turn. The rendered comparison makes the intended distinction visible: A reorients the scene with the turntable; B shows the carrier turning within an unchanged reference. That observation does not establish which version players understand better.

[Turntable A](isometric-turntable-A.png) · [Turntable B](isometric-turntable-B.png) · [Tilt B](isometric-tilt-B.png)

## Manual inspection layer

After the automatic comparison, manual orbit was added independently of the ground reference:

- Right mouse drag: orbit around the fixed puzzle centre.
- Mouse wheel: change orthographic zoom, bounded to 0.65–1.4 times the recommended size.
- Home / Reset isometric view: restore recommended manual yaw, elevation and zoom within the current transported ground reference.
- Elevation stays between 25 and 70 degrees. No panning or free flight.
- Q/E rotate structures. Tab switches perspective without resetting the view.

Drag/zoom operate only in architectural view while settled, unpaused and not complete. Mouse release over UI, focus loss, pause and view changes cancel dragging. The settings menu also provides a reset button. First-person mouse input never writes the overview's manual state.

[Manual inspection example](isometric-manual-orbit.png)

Snapshots preserve both the world reference and manual view, so undo and save/restore retain the chosen framing. Earlier saves containing only `camera_bias` reconstruct their original overview with default manual offsets. Restarting a study restores its initial framing; Home resets only inspection framing, without moving the player or changing structures.

## Verification

`overview_tests.gd` is included in the positioning suite and prints `OVERVIEW SELF TEST PASS`. It now verifies ground-normal transport (0-degree camera rotation on a 90-degree turntable, 90 degrees on a tilt), passenger-local pose and world attachment, unrelated turns, same-normal seams with different axes, deterministic antipodal fallback, first-person look/Tab independence, actual drag/wheel/Home input handlers, UI drag release, bounded elevation/zoom, persistence, undo and old-save migration. A 280-frame curve traversal checks the chosen manual view remains consistent in the transported reference with no heading jump at its seams.

The positioning and original gallery suites pass, including after import of a clean staged checkout without the local MCP addon. Historical rendered inspection covered A/B examples, tilted ground, a manually orbited view and the comparison settings. The old third-person Jev runner is not used as evidence of overview readability.

## Further playtesting

The original A/B build and comparison settings remain available at commit `6e85e85`, with the images above preserving its visual evidence. The user has now chosen B, so the live game no longer asks players to choose a transport implementation.

With the current build, compare an occupied turntable and a tilt at recommended framing before introducing manual orbit. Ask players what moved, where their ground is, and which connection opened. Then inspect a hidden connection, use Tab twice, and turn the carrier to check whether the chosen view remains understandable. Record their explanations and any discomfort; passing tests establishes the intended transformations, not player comprehension or comfort.
