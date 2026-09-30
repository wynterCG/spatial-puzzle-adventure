# Prototype validation

Verified on 30 September 2026 with Godot 4.6.1, Compatibility/OpenGL, and the user's Godot MCP Pro 1.17.1.

## Automated mechanics checks

`--headless --quit-after 120 -- --self-test` exits 0 and prints `SELF TEST PASS`.

- Physically touching arrival/carrier seam transfers support.
- Carrier transformation preserves support-local position and normal.
- A rotated, disconnected carrier cannot attract the player across the gap.
- Top/side/underside traversal remains continuous.
- State B carrier connects to the courtyard.
- Snapshot restoration restores support as well as structure state.
- An inactive arch cannot transport the player.
- An active arch maps the player to the destination.
- Repeated diagonal corner traversal remains within support bounds.
- Rotating a side-face passenger changes world up while retaining local up.

## Live MCP Pro checks

Connected through the bundled CLI and confirmed project path, engine version and addon services. Opened and ran the main scene through MCP Pro. Exercised the complete route using the actual walker and manipulation functions in the running game:

1. Walked from arrival onto the carrier in state A.
2. Rotated the occupied carrier to B; verified its support-local pose and transformed world position.
3. Walked onto the courtyard.
4. Selected and aligned the arch; confirmed active passage state.
5. Returned to first person; visually inspected the destination rendering through the opening.
6. Walked through the passage to the separate destination and reached the light.
7. Confirmed `boarded`, `reached_court`, `crossed` and `won` were true, with `busy` false.

Verified Escape opens settings, the menu fits the viewport, and key rebinding accepts I (73) and restores W (87). Checked default camera switching through action events. Reset progress to the arrival afterward. The final fresh runtime log has no script errors.

## Visual evidence

- [Architectural overview](prototype-preview.png)
- [First-person passage](passage-preview.png)
- [Completion](completion-preview.png)
- [Settings](settings-preview.png)

These are runtime screenshots captured through MCP Pro. The gameplay remains a mechanical prototype. This verification does not replace human comfort/playability testing or resolve the production limitations listed in [spec.md](spec.md).
