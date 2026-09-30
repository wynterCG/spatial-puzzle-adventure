# Positioning studies - validation

Validated 2026-09-30 with Godot 4.6.1 Mono / Compatibility. The three studies are the default scene; the original gallery remains a separate optional experiment. Historical gallery evidence is in [gallery-validation.md](gallery-validation.md).

## Automated mechanical checks

Both headless suites pass with exit 0 and their literal PASS markers:

A clean staged checkout also imported successfully and passed both suites without the local MCP addon or machine-specific configuration.

- `POSITIONING SELF TEST PASS`: all three solutions use real walking substeps and actual rotation commands, reach the physical goal and trigger completion. Checks cover the incorrect short deck, the fixed-landing transfer, receiver obstruction in both directions, rejected-turn snapshot/history preservation, undo, authored winning contact, and camera-mode state preservation.
- Exhaustive settled-orientation checks in Studies 1 and 2 verify that the wrong path never joins the goal, the correct path never joins the starting platform directly, and the two carrier paths never join each other.
- A 280-frame traversal around the curved track checks finite camera transforms, minimum pivot separation, world-up screen orientation, an upside-down avatar and a ground-relative overview.
- The original gallery's `SELF TEST PASS` covers local interactions, the rounded track and return, authored boundaries, passenger rotation, overview/cutaway behavior, camera cases, undo, gallery clearance and two-way concealed crossing.
- `node --check` passes for both Jev runners. The original runner's scene guard rejects the new studies before accessing gallery-specific state. The separate camera runner exercises the new scene (see below).

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

The curved walkway tail ends at the lower landing edge instead of overlapping its paving. The Study 2 hub uses slender structural arms, leaving the separate paths legible. The world-up camera keeps its screen upright and now avoids obstructions through bounded orbit changes rather than a sudden swap to the surface-relative arm.

## Third-person curve regression

Reproduced two faults through MCP: the old obstruction fallback jumped up to 11.05 units and flipped 180 degrees in a single 60 Hz frame; recalculating forward after a key release or blocked step reversed W on the curved track. The previous finite-transform checks did not catch either fault.

`camera_tests.gd`, included in the positioning suite, checks eight camera configurations spanning four azimuths and the distance/pitch limits. Maximum measured displacement is now 0.642 units and angular change 4.774 degrees per 60 Hz frame in this matrix. It also exercises actual W/S input alignment, repeated stops, a pitch change, small mouse yaw on the wall, isometric toggles and a first/third-person round trip. W finishes on the lower landing and stays there at its boundary; S returns to Arrival.

Jev is used through the TypeSafe API with structured observations, not screenshots. The first exploratory run exhausted its 36-action budget by reversing near the entrance; its [trace is preserved](jev-camera-exploratory-report.json). A second, directed runner restricts movement to the outward leg and then the return leg while Jev chooses the order/timing of stop, pitch, orbit and view-switch checks. This is regression coverage, not evidence of blind puzzle understanding.

The [directed Jev run](jev-camera-report.json) passed in 22 actions: lower landing reached, stop/restart, pitch, orbit and both view changes covered, then return to Arrival. All reported camera transforms remained finite and upright, with frame displacement below 0.65 units and rotation below 8 degrees. The live scene state was restored after the run.

Inspected the [updated third-person view on the curved wall](camera-curve-stability.png): the traveller remains visible, the screen stays world-upright and the arm clears the track. The camera regression and original gallery suite also pass from a clean staged checkout without the MCP addon.

## Limits

These checks establish implemented routes and selected counterexamples, not a proof over every continuous player position. Rotation clearance samples sixty points per quarter turn with a small docking tolerance; it is not continuous rigid-body collision simulation. Camera clearance checks and screenshots do not establish human comfort.

The studies still need a blind human playtest using [playtest.md](playtest.md). In particular, verify whether players can explain why their chosen action order was necessary, recognize the receiver's blocking arms, and use isometric view to recover their bearings without a hint.
