# Positioning studies - validation

## Turning-frame study — 1 October 2026

Positional-choice review: the existing puzzle already creates a correct arrangement with the player on the wrong passage. A Godot MCP Pro run reached that state, then returned to the arrival and completed from the longer ledge using normal walking and turns, without reset. [Wrong-passage evidence](monument-wrong-passage.png) shows the disconnected occupied path and connected destination. The taller landmark was cropped in that inverted view; the monument's fixed focus/scale now keep it above the footer. Added projected-mesh framing checks for both occupied passages across all four orientations. No walking region, connection or mechanism changed.

Final positioning and original-gallery suites pass with exit 0, explicit PASS markers and empty stderr on **Godot 4.6.1 Mono and 4.7.2 Steam**, using an addon-free copy of the final scripts. The monument marker includes `overview framing from both passages`. MCP visual review ran in an isolated project/user-data copy under 4.7.2. The user's editor, running play session and pre-existing `project.godot` feature-version edit were preserved. This covers the selected regression suites and rendered cases, not comprehensive engine compatibility or human readability. The [new monument-first playtest](playtest.md#turning-frame-first-when-assessing-the-monument) records the latter questions.

Follow-up refinement: the destination arch and floor beacon were replaced with a projecting balcony, slender fixed pier and suspended lantern. Moving passages gained low kerbs outside their authored walking regions. MCP Pro inspection caught a broad pier hiding the light; the final pier is narrower and offset to the rear corner. Updated arrival/overview/underside captures show the final geometry. A live mouse/forward/Tab/E traversal again reached `Lantern_landing` with `won = true`.

That earlier destination refinement passed both regression suites with exit 0 and PASS markers in a freshly imported clean staged checkout using Godot 4.6.1. These include all four frame configurations, incorrect boarding, premature turning, both roll directions and reverse travel. The review used a separate MCP-enabled project copy and separate user-data directory because the user's Godot 4.7.2 editor had no active MCP plugin connection. The user's running game, progress and pre-existing `project.godot` version change were left untouched. The 4.7.2 results above were obtained during the subsequent positional-choice review.

The separate [monument study](monument-study.md) retains every earlier puzzle and adds one architectural assembly. `MONUMENT SELF TEST PASS` verifies all four configurations, the upper-path counterexample, remote turning before boarding, ordinary recovery without restarting, both solving roll directions, full reverse traversal, restart, independent save identity, reload, undo and completion. First-person held-W traversal around the integrated curve is also checked. Headless Godot cannot capture the mouse, so that test calls the same look handler directly; live input dispatch was verified separately.

Through Godot MCP Pro, a mouse-look event and held forward input reached the underside ledge; physical Tab and E key events turned the occupied frame twice; forward input reached `Lantern_landing` and set completion. Rendered inspection covered [default overview](monument-overview.png), [arrival](monument-arrival.png), [underside](monument-underside.png), the completion explanation and the scrollable menu. The game was returned to the study entrance in first person, with processing enabled and only its own save reset. Existing courtyard progress was backed up before testing and is kept separate.

Both full headless suites passed with exit 0 and their PASS markers, including a newly imported clean staged checkout without the proprietary addon or local configuration. The original gallery suite still passes; the positioning suite includes the three original studies, Lantern Fold, camera B, courtyard and monument.

The study establishes a mechanically valid positional choice in a consolidated form. It reuses Study 1's dependency and does not establish novel puzzle depth. The underside forward view is still visually sparse. Human understanding, architectural presence and camera comfort remain to be assessed; screenshots and scripted traversal are not a blind playtest. No new Jev run is claimed.

Validated 2026-09-30 with Godot 4.6.1 Mono / Compatibility. The Lantern Fold and three preserved studies share the default scene; the original gallery remains a separate optional experiment. Historical gallery evidence is in [gallery-validation.md](gallery-validation.md).

Latest camera decision: first person is now the default in the walker and both settings loaders. The running game's first-person preference was saved without moving the player or changing its paused state. Both headless suites pass. The third-person reports below are retained as experimental history, not the current primary design direction.

The user selected ground-direction transport (B), reporting "it reads way better". It is now the sole overview behavior for the positioning studies; the A/B selector and full-support alternative are removed. Older A preferences are ignored and cleared when preferences are saved. The retained `OVERVIEW SELF TEST PASS` checks that an occupied horizontal turn produces no camera yaw while a tilt carries the camera 90 degrees, with full passenger attachment throughout. It also covers curved traversal, seams, manual input, bounds, look/Tab independence, reset, undo and save migration. [Historical A/B evidence and current behavior](isometric-camera-experiment.md) distinguish this user preference from broader readability testing.

## Turning-courtyard revision

The user completed the courtyard but reported that needing to invert the gallery to free the ring was unclear. The first static highlight/ghost was still unclear to the user. The revised preview animates a copy of the whole ring up to the bracket and adds a contact pointer: "Ring hits this bracket." Feedback states the consequence of moving the gallery. Reduced-motion mode shows the stopped pose immediately. It appears on turn-button hover as well as rejection. Tests verify the preview starts at the current pose, stops at the sampled collision, expires, respects reduced motion, and never moves the real ring/player or changes undo. Both vertical and inverted withdrawal still permit the solution. Human understanding of the revised feedback remains unvalidated.

The previous sequential chapter is replaced by a compact courtyard. `CHAPTER SELF TEST PASS` covers both solving ring directions, physical obstruction at both galleries, remote pre-rotation, remaining aboard the access gallery, premature far-gallery deployment and recovery, all 64 contact configurations, full reverse traversal, rejected-turn immutability, serialized saves and undo, completion/reopened reflection, full terrace contact and stable overview composition. A reflection-after-return test exposed a finished-tween resume error; pause now resumes only an active turn.

Godot MCP Pro inspection checks the actual rendered arrival, the whole courtyard in overview, named obstruction feedback, the first-person underside path, completion and settings. Screenshots: [overview](chapter-courtyard.png), [arrival](chapter-arrival.png), [blocked access](chapter-clearance.png), [inhabited underside gallery](chapter-interior.png). The three assemblies use consistent terracotta/violet/teal colours and matching selector labels. Fixed structure is blue-grey. Windowed end piers and a far colonnade leave more of the mechanism visible as the B camera changes ground.

The earlier `chapter-relay.png` is retained as historical evidence of the superseded layout. Progress for that layout remains in `chapter-one.save`; the revision writes only `chapter-courtyard.save`. Existing studies and gallery saves retain their own paths.

Both headless suites pass with exit 0 and no script errors, in the working project and a clean staged checkout imported without local addons. A live clear ring sweep measured 2,097 ms before conservative distance culling and 179 ms afterward on this machine; nearby geometry still receives all 60 SAT samples and body clearance is unchanged. This is a selected measurement, not a frame-rate benchmark.

These checks establish specific mechanical cases and selected rendered views, not human comprehension, atmosphere, colour accessibility or motion comfort. The blind playtest protocol is in [first-chapter-plan.md](first-chapter-plan.md).

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
