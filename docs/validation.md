# Positioning studies - validation

Validated 2026-09-30 with Godot 4.6.1 Mono / Compatibility. The Lantern Fold and three preserved studies share the default scene; the original gallery remains a separate optional experiment. Historical gallery evidence is in [gallery-validation.md](gallery-validation.md).

Latest camera decision: first person is now the default in the walker and both settings loaders. The running game's first-person preference was saved without moving the player or changing its paused state. Both headless suites pass. The third-person reports below are retained as experimental history, not the current primary design direction.

The user selected ground-direction transport (B), reporting "it reads way better". It is now the sole overview behavior for the positioning studies; the A/B selector and full-support alternative are removed. Older A preferences are ignored and cleared when preferences are saved. The retained `OVERVIEW SELF TEST PASS` checks that an occupied horizontal turn produces no camera yaw while a tilt carries the camera 90 degrees, with full passenger attachment throughout. It also covers curved traversal, seams, manual input, bounds, look/Tab independence, reset, undo and save migration. [Historical A/B evidence and current behavior](isometric-camera-experiment.md) distinguish this user preference from broader readability testing.

## Connected chapter blockout

`CHAPTER SELF TEST PASS` covers the full physical route through three assemblies, wrong-path and stay-aboard counterexamples, backtracking to the overlook, serialized save/reload, undo across assembly boundaries, separate save paths, completion and continued exploration. It samples framing transitions while checking that the ground frame and manual angle remain unchanged. All previous suites still pass.

Godot MCP Pro inspection covers the opening sightline to the final landmark, all three overview regions, the first-person underside approach and the chapter UI. The chapter's controls are placed beneath the title to leave onward connections visible. The landmark extends to both sides of the final ground plane. These are implementation and selected visual checks; a blind learning-progression playtest is still required.

## Complete puzzle - The Lantern Fold

The fourth layout retains the three study builders and the original gallery. `LANTERN SELF TEST PASS` verifies the full route with both roll directions, the failed upper-path attempt, all 16 settled structure combinations for forbidden bypass links, blocked-turn snapshot/history preservation, recovery by withdrawal, receiver clearance in both directions, save/undo, restart, and migration of old three-study completion flags.

Godot MCP Pro also ran the complete puzzle suite in the live scene with no failures and reached the Lantern terrace. Rendered inspection covered [the initial overview](lantern-fold-overview.png), the underside overview, first person on the underside, rejected-turn feedback, and the revealed completion explanation. These establish a playable route and selected visual checks; human difficulty and comprehension remain unvalidated.

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

The curved walkway tail ends at the lower landing edge instead of overlapping its paving. The Study 2 hub uses slender structural arms, leaving the separate paths legible. The world-up camera now preserves mouse-owned azimuth; see the current regression notes below.

## Earlier third-person fix - superseded after user feedback

Reproduced two faults through MCP: the old obstruction fallback jumped up to 11.05 units and flipped 180 degrees in a single 60 Hz frame; recalculating forward after a key release or blocked step reversed W on the curved track. The previous finite-transform checks did not catch either fault.

`camera_tests.gd`, included in the positioning suite, checks eight camera configurations spanning four azimuths and the distance/pitch limits. Maximum measured displacement is now 0.642 units and angular change 4.774 degrees per 60 Hz frame in this matrix. It also exercises actual W/S input alignment, repeated stops, a pitch change, small mouse yaw on the wall, isometric toggles and a first/third-person round trip. W finishes on the lower landing and stays there at its boundary; S returns to Arrival.

Jev is used through the TypeSafe API with structured observations, not screenshots. The first exploratory run exhausted its 36-action budget by reversing near the entrance; its [trace is preserved](jev-camera-exploratory-report.json). A second, directed runner restricts movement to the outward leg and then the return leg while Jev chooses the order/timing of stop, pitch, orbit and view-switch checks. This is regression coverage, not evidence of blind puzzle understanding.

The [earlier directed Jev run](jev-camera-b921456-report.json) passed in 22 actions: lower landing reached, stop/restart, pitch, orbit and both view changes covered, then return to Arrival. All reported camera transforms remained finite and upright, with frame displacement below 0.65 units and rotation below 8 degrees. The live scene state was restored after the run. **The user subsequently reported worse movement and camera behavior. Those checks did not establish usable general controls.**

Inspected the [updated third-person view on the curved wall](camera-curve-stability.png): the traveller remains visible, the screen stays world-upright and the arm clears the track. The camera regression and original gallery suite also pass from a clean staged checkout without the MCP addon.

## Current regression: camera ownership and ordinary movement

Captured the reported live state on Arrival. The stored walking heading had a dot product of only 0.223 with the camera's projected forward: W was nearly sideways relative to the view. The previous fix locked that transported heading on all surfaces and integrated mouse steering separately from the visible camera. Its automatic obstacle search also changed the chosen azimuth.

Removed the obstacle side-search and persistent platform heading. Ordinary platforms now establish camera-relative controls on a fresh gesture; only an authored curve preserves controls through release/restart. Added screen-right handedness for upside-down ground and a check for a mouse event arriving before the camera frame update.

A rendered test rejected a zoom-only version: it met continuity checks but pushed the camera into the avatar at the curved wall. The current version uses a [local translucent track cutaway](camera-curve-cutaway.png) at that obstruction, keeping a roughly five-unit arm in the inspected case. It restores the opaque track in overview and retains physical walking/body constraints. This is a visual tradeoff that still needs user feedback. Alpha blending follows [Godot's standard-material transparency support](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html#transparency).

The expanded suite checks fresh W/D against the visible view on upper and underside platforms at four azimuths, stale-heading recovery, a single mouse event before movement alignment, stationary mouse look, unchanged mouse-owned azimuth around the curve, adequate framing at the wall and complete material restoration in isometric view. The eight camera configurations currently measure maximum 0.629 units / 1.111 degrees per 60 Hz frame. Both mechanical suites pass. These are targeted checks, not a claim that all camera situations are solved.

The [current directed Jev run](jev-camera-report.json), using Jev 1.13.0, completed the same 22-action outward/return scenario with stop, pitch, orbit and view-switch coverage. It passed its continuity checks. Ordinary platform control alignment and cutaway restoration are covered separately by the expanded local tests and rendered inspection; Jev's structured observations do not establish visual comfort.

## Limits

These checks establish implemented routes and selected counterexamples, not a proof over every continuous player position. Rotation clearance samples sixty points per quarter turn with a small docking tolerance; it is not continuous rigid-body collision simulation. Camera clearance checks and screenshots do not establish human comfort.

The studies still need a blind human playtest using [playtest.md](playtest.md). In particular, verify whether players can explain why their chosen action order was necessary, recognize the receiver's blocking arms, and use isometric view to recover their bearings without a hint.
