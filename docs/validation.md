# Positioning studies - validation

Validated 2026-09-30 with Godot 4.6.1 Mono / Compatibility. The three studies are the default scene; the original gallery remains a separate optional experiment. Historical gallery evidence is in [gallery-validation.md](gallery-validation.md).

## Automated mechanical checks

Both headless suites pass with exit 0 and their literal PASS markers:

A clean staged checkout also imported successfully and passed both suites without the local MCP addon or machine-specific configuration.

- `POSITIONING SELF TEST PASS`: all three solutions use real walking substeps and actual rotation commands, reach the physical goal and trigger completion. Checks cover the incorrect short deck, the fixed-landing transfer, receiver obstruction in both directions, rejected-turn snapshot/history preservation, undo, authored winning contact, and camera-mode state preservation.
- Exhaustive settled-orientation checks in Studies 1 and 2 verify that the wrong path never joins the goal, the correct path never joins the starting platform directly, and the two carrier paths never join each other.
- A 280-frame traversal around the curved track checks finite camera transforms, minimum pivot separation, world-up screen orientation, an upside-down avatar and a ground-relative overview.
- The original gallery's `SELF TEST PASS` covers local interactions, the rounded track and return, authored boundaries, passenger rotation, overview/cutaway behavior, camera cases, undo, gallery clearance and two-way concealed crossing.
- `node --check tools/jev_playtest.mjs` passes. Its scene guard rejects the new studies before accessing gallery-specific state. No new Jev API run was performed: this runner remains specific to the original gallery and observes structured state, not screenshots.

Commands from the project root:

```powershell
& $godot --headless --path . --quit-after 120 -- --self-test
& $godot --headless --path . scenes/main.tscn --quit-after 120 -- --self-test
```

## Rendered inspection through Godot MCP Pro

Inspected the running 1280 x 800 game with its 1440 x 900 UI viewport. Each study fits its overview. The settings panel and completion/reflection panel fit the window, including the revealed explanation. A live Study 1 solution reached `Exit`, set `won = true`, and reported no solution-test failures.

- [Study 1: separate carrier decks and fixed curved route](study-1-decks.png)
- [Study 2: fixed landing and paths on different ground](study-2-landing.png)
- [Study 3: carrier, docking arms and receiver](study-3-receiver.png)
- [World-aligned third person: inverted avatar on the lower landing](study-world-camera.png)

The curved walkway tail now ends at the lower landing edge instead of overlapping its paving. The Study 2 hub uses slender structural arms, leaving the separate paths legible. The world-up camera keeps its screen upright; when its normal arm is obstructed, it moves to the open side of the surface without rolling the screen.

## Limits

These checks establish implemented routes and selected counterexamples, not a proof over every continuous player position. Rotation clearance samples sixty points per quarter turn with a small docking tolerance; it is not continuous rigid-body collision simulation. Camera clearance checks and screenshots do not establish human comfort.

The studies still need a blind human playtest using [playtest.md](playtest.md). In particular, verify whether players can explain why their chosen action order was necessary, recognize the receiver's blocking arms, and use isometric view to recover their bearings without a hint.
