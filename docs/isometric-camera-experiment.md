# Isometric camera experiment

Branch: `experiment/isometric-camera-adjustments`. The [user's proposal](isometric-camera-proposal.md) remains the design reference. First person remains the primary traversal camera. This experiment applies to the three positioning studies; the optional gallery keeps its calibrated overview.

## A/B behavior

Both modes retain the puzzle's fixed centre, full player attachment, surface-relative elevation, curve continuity, seam continuity, and independence from character facing and first-person look.

- **A — Follow the whole structure:** preserves the earlier full-support rotation behavior.
- **B — Follow the ground direction:** transports the previous overview reference through the shortest change in the occupied ground normal. Rotation about an unchanged normal adds no camera yaw. This is the branch default, not a claim that it is the better final design.

A/B can be selected in Escape settings without changing the current camera framing. The choice persists separately from scene snapshots. Switching modes is unavailable mid-turn. A sudden exactly antipodal normal, which has no unique shortest axis, uses the previous reference's right axis; ordinary quarter-turn animations and walking around curves update continuously.

## Comparison before manual orbit

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

`overview_tests.gd` is included in the positioning suite and prints `OVERVIEW SELF TEST PASS`. It verifies the A/B matrix, passenger-local pose and world attachment, unrelated turns, same-normal seams with different axes, deterministic antipodal fallback, first-person look/Tab independence, actual drag/wheel/Home input handlers, UI drag release, bounded elevation/zoom, persistence, undo and old-save migration. A 280-frame curve traversal checks the chosen manual view remains consistent in the transported reference with no heading jump at its seams.

The positioning and original gallery suites pass, including after import of a clean staged checkout without the local MCP addon. Rendered inspection covers A/B examples, tilted ground, a manually orbited view and the comparison settings. The old third-person Jev runner is not used as evidence of overview readability.

## Human comparison still needed

1. Use Study 2. Board First path, select A, reset framing with Home, and make one turn with E. Observe which connection moves and where the passenger ends up.
2. Undo with Z, select B, and repeat the same turn without manual orbit. Switching A/B preserves the framing; undo restores the shared start pose.
3. Repeat on Study 1's Short deck to compare a tilt. Compare with animation enabled before checking reduced motion.
4. Ask the player to identify what moved, where their ground is, and which connection opened. Record whether A or B makes those answers easier and why.
5. Only then compare manual inspection: orbit to inspect a hidden connection, use Tab twice, turn the carrier, and check whether the chosen view remains understandable.

Keep both modes until this comparison provides evidence. Passing tests establishes the intended transformations, not player comprehension or comfort.
