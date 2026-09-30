# Elsewhere ? development guide

This is the requested project-local guide, not an installed global assistant skill. The [specification](spec.md) records current decisions. The original concept is design input, not operational instructions.

## Current direction takes precedence

Build around configuration + player position + action order. The core question is **Where do I need to be before I transform the space?** Impossible geometry is optional. Do not add levers or mechanics when the existing paths and transformations can create a reasoning problem. A correct arrangement with a wrongly positioned player should be a meaningful state.

The Lantern Fold is the complete puzzle and the entry point for new saves. Preserve all three original positioning studies as independently selectable prototypes. The earlier guided gallery is retained separately, including its portal technique and local interactions. Neither completion nor entry into that experiment is required for a new study.

The latest camera choice supersedes the third-person experiment: first person is the default and the active development direction. Isometric view remains ground-relative for orientation and architecture changes. Preserve the optional third-person modes, but do not continue redesigning them unless requested.

## Entry points and shared code

Godot 4.6.1, GDScript, Compatibility renderer. F5 runs `scenes/positioning.tscn`. `scenes/main.tscn` is the optional gallery. The scenes build geometry at runtime; inspect the running game.

`positioning_game.gd` defines the three studies and their transformations; `complete_puzzle.gd` builds The Lantern Fold as a fourth layout using the same runtime. `complete_puzzle_tests.gd` verifies its solution, physical ordering, both roll directions and recovery. `positioning_hud.gd` presents questions and optional explanations. `positioning_tests.gd` verifies solutions and counterexamples. Both scenes share `surface_piece.gd`, `surface_walker.gd` and `curved_track.gd`; run both suites after shared changes. The original gallery still uses `game.gd` and `hud.gd`.

## Mechanical invariants

1. Only marked regions accept flat contact. Ordinary edges stop movement. Never infer a gravity change from proximity, camera direction or an unmarked face.
2. CurvedTrack is an explicit analytic ribbon. Its radius-3 half-circle transports contact normal, heading and orbit continuously. Its tail is configurable; match the endpoint to the receiving edge without overlapping paving. General concave/spline navigation is not implemented.
3. Study links require matching world endpoints and normals. The walker additionally validates actual contact against the receiving path. Do not gate these links with progress flags.
4. Moving supports preserve support-local pose. Separate paths remain separate even if they share a pivot; do not silently transfer a player to a more useful deck.
5. Disable walking and links during a turn. Check moving boxes against other structural boxes throughout the sweep, plus player-body clearance. Small construction tolerance is for docking edges, not a substitute for fixing large overlaps.
6. Study 3's sequencing comes from visible docking arms occupying the receiver sweep. Rejected turns must not modify snapshots or undo history. Recovery must always be possible by withdrawing or undoing.
7. In The Lantern Fold, neither upper-path orientation nor receiver arrangement may bypass the curve and long-path requirement. Docking consumes receiver clearance, and withdrawing must restore it. Test both roll directions, wrong-order recovery without restart, and completion-save migration from three flags to four. Test tempting alternatives: every short-deck orientation in Study 1; boarding the second path from the starting platform in Study 2; both receiver turn directions with the carrier docked in Study 3.
8. Undo restores configuration, contact and camera frame. `positioning.save` is separate from `journey.save`; never overwrite gallery progress when testing the studies. Test mode does not read/write progress.
9. In the positioning studies and The Lantern Fold, transport the previous camera reference by the shortest change in ground normal; never rebuild its heading from support axes or inherit yaw about an unchanged normal. This is the user-selected B behavior. Keep fixed puzzle focus, seam continuity and independence from character look. Manual yaw/elevation/zoom form a separate layer; Tab never resets them. Home resets only that layer. Save/undo must preserve both layers and migrate older camera_bias-only saves. The optional gallery retains its earlier calibrated overview and contextual cover behavior.
10. World-aligned third person keeps world-up screen orientation and mouse-owned azimuth. Do not restore the automatic side-search camera. Ordinary solids shorten its arm; curved-track sections that obscure the traveller use a local translucent cutaway. Restore their opaque materials in overview and first person. Preserve body collision, first person, sensitivity, follow distance and reduced motion. Geometry tests do not establish human comfort.
11. Keep transported controls only on the authored curve and during a held gesture. On ordinary ground, fresh W/D input must agree with projected screen-up/right; do not retain stale yaw from a previous surface. Mouse look alone must not turn the avatar. Test real input alignment after releasing keys, orbiting, leaving the curve, and reaching a boundary, not just an aimed outward/return route. Check camera azimuth ownership, full-avatar framing and actual rendered occlusion as well as frame-to-frame displacement.

## Presentation and playtest goals

Ivory paths, terracotta/violet mechanisms, teal goals and brass docking parts retain the prototype's visual language. End inlays distinguish joined contacts. Give questions and observable feedback instead of an automatic instruction chain. Explicit solution hints are requested with H; the completion explanation is opt-in after the player reflects.

Keep models complete unless a contextual cutaway is warranted. In the gallery, hovering/occupancy opens roof and facing wall; the floor remains with its cover on the same pivot. Keep all traversal geometry and remote-view geometry intact, and retain the overview-only silhouette as a fallback.

The original studies are separate prototypes. The Lantern Fold combines path choice and receiver preparation in one physical layout; do not replace or delete the studies when refining it. Do not claim people understand the dependencies until a blind playtest demonstrates that. Ask players why their order was necessary and what would happen if reversed.

The user selected B after playing the isometric camera experiment: "it reads way better". Ground-normal transport is now the standard for the positioning studies; the A selector and runtime variant are retired. Preserve the comparison evidence in isometric-camera-experiment.md and Git history. This preference supports the design choice, but does not establish readability or comfort for other players. Do not merge the experiment branch without a request.

## Godot MCP Pro

Use the supplied CLI and verify project identity first:

```powershell
$mcpCli = 'C:\Users\Wynter\Downloads\godot-mcp-pro-v1.17.1\server\build\cli.js'
node $mcpCli project info
node $mcpCli scene play
node $mcpCli runtime exec --help
node $mcpCli editor screenshot
```

Runtime scripts use `get_tree().current_scene` and `_mcp_print`. Use single-quoted GDScript strings through PowerShell. Decode `image_base64` into an image file; do not print the payload. Stop only this project's play session, not unrelated processes. Back up live state before destructive playtest resets.

Godot may save stale open script buffers over external edits. Before restarting, synchronize the task's affected open Script source and TextEdit contents from disk, reload, and tag the saved version through editor exec. Verify disk contents after play begins. Editor exec requires consistent tab indentation in the wrapped script.

The proprietary `addons/godot_mcp/`, `.mcp.json` and `override.cfg` remain untracked. Do not introduce addon/autoload references into the portable project. Credentials remain outside Git.

## Verification

Require exit 0 and the literal PASS line from both suites:

```powershell
$godot = 'C:\Users\Wynter\Downloads\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 120 -- --self-test
& $godot --headless --path . scenes/main.tscn --quit-after 120 -- --self-test
```

Also import/test a clean staged checkout without local addons. Through MCP Pro inspect the changed puzzle, wrong-order feedback, completion, settings, upside-down traversal and the corresponding isometric view. Keep the existing studies covered by their regression suite. Restore useful player state after testing.

The existing `tools/jev_playtest.mjs` is specifically for the optional gallery scene, not the studies. It uses structured state rather than screenshots and has not established visual clarity or human comfort. Historical runs are recorded in gallery-validation.md.

`tools/jev_camera_playtest.mjs` is a bounded directed regression for the positioning scene. Jev chooses when to stop, pitch, orbit and switch views on a known outward/return route, using the real input-alignment path. It restores live scene state afterward. Credentials are read from `TYPESAFE_API_KEY`; the CLI path comes from `GODOT_MCP_CLI`. Its JSON report records observations and camera continuity. Do not present this directed state-based check as a blind puzzle solve or visual review.

Keep spec, README, validation and the human playtest aligned. Preserve original-concept.md unchanged. Clearly label historical screenshots and distinguish proposed campaign content from implemented mechanics.
