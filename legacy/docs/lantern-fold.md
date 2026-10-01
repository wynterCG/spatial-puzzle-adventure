# The Lantern Fold

A complete prototype puzzle built as a fourth layout. The three original studies and optional gallery remain available from Escape. New saves start here; an existing save resumes its current puzzle.

![Initial overview](lantern-fold-overview.png)

## Player objective

Reach the lantern across the gap. First person explores the authored paths; isometric view reveals the whole arrangement and controls the two machines. The ground-direction camera chosen in the A/B comparison remains in use.

## Layout

| Part | Purpose |
|---|---|
| Arrival | Fixed starting platform, joined to the upper path and rounded ribbon |
| Arrival curve | Explicit half-circle gravity transition to the underside |
| Underside landing | Fixed boarding point for the longer moving path |
| Turnover | One horizontal pivot carrying two separate paths; only the longer path reaches the dock |
| Receiver | L-shaped walkway rotating around a vertical pivot; alignment connects the dock to the terrace |
| Lantern terrace | Fixed destination with a visible beacon and completion trigger |

The two machines share a physical docking interface. Brass arms are attached beneath the long path by a crossbar. They clear the prepared receiver during either half-roll direction, but block its sweep while docked. Matching contact positions and normals determine walking connections; no milestone flag enables them.

## Solution and dependencies

1. Prepare the Receiver: select **2**, then **Q** once from the initial layout.
2. Follow the rounded ribbon from Arrival to the underside landing and board the long path.
3. In overview, select **1** and roll twice in either direction.
4. Walk across the dock, follow the Receiver's bend and reach the lantern.

Preparation and boarding can occur in either order. What matters is being on the long path when it moves, and having the receiver ready before docking occupies its clearance. If the player docks early, one turn back withdraws the arms; they can arrange the receiver and return. This recovery requires neither restart nor a hidden reset condition.

Rotating while aboard the upper path is another useful mistake: even with the receiver aligned, that path ends short of the connection. The character remains on the same support-local path through the turn. Undo or returning the Turnover restores access to the fixed approach.

## Complete interaction loop

The initial overview shows the arrival, both machines and destination together. Select structures with **1/2** or the panel; **Q/E** turns them. **Tab** switches to first person; **WASD/mouse** moves and looks. Right-drag and wheel inspect the overview; **Home** resets its manual framing.

**H** offers three optional hints. Rejected turns name the obstruction and preserve state. **Z** restores the previous turn and passenger position; **R** restarts this puzzle. Settled saves retain the arrangement, current contact and camera. Completion offers an optional explanation, replay and puzzle selection.

## Verification and limits

`complete_puzzle_tests.gd` is part of the standard positioning self-test. It walks the full physical route in both roll directions, verifies wrong-path and premature-docking attempts, tests recovery without restart, checks all 16 settled arrangements for bypass connections, and covers rejected-turn state preservation, undo, save/restore, restart and old completion-flag migration. The original study and gallery suites remain required.

Live Godot MCP Pro inspection covers the overview, first-person underside, ground-relative inversion, blocked turn and completion with explanation. The level is complete as a playable prototype. Production art, sound design, a larger campaign and blind difficulty/readability testing remain outside this implementation.
