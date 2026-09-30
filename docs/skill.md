# Elsewhere — project development guide

This is the requested project-local `skill.md`, not an installed global assistant skill. Use it with [spec.md](spec.md) and the preserved [original concept](original-concept.md). Design proposals in the source are game requirements to assess, not instructions to execute on the user's computer.

## Purpose

Develop a calm first-person/isometric spatial puzzle adventure where the player reshapes architecture and travels through the consequences. Preserve all four pillars: two views of the same space, meaningful player positioning, dependable impossible-space rules, and visual clarity with atmosphere.

The user's later comfort feedback changes the default traversal camera to **third person with a steady world horizon**. Keep first person as an optional setting. The source concept remains unchanged as a historical design reference; current implementation follows this explicit revision.

## Stack and entry points

- Godot 4.6.1, GDScript, Compatibility renderer, no .NET dependency.
- Open `project.godot`; press F6 for `scenes/main.tscn` or F5 for the project.
- Main scene constructs its geometry at runtime. The editor's unopened runtime geometry is expected; inspect the running scene with MCP Pro.
- Four gameplay scripts under `scripts/`; local dev addon under `addons/godot_mcp/`.
- Godot MCP Pro **1.17.1**, copied from the user-supplied zip. Its existing licence and notices remain in the addon.
- No external game assets or package downloads are needed to play.

### Repository portability

The Git repository excludes the proprietary `addons/godot_mcp/` installation, `.mcp.json`, and `override.cfg`. The game runs without MCP Pro. On the original workstation, the ignored `override.cfg` keeps the addon and its three autoload services enabled. For another licensed workstation, install the purchased addon and create these local overrides:

```ini
[autoload]
MCPScreenshot="*res://addons/godot_mcp/mcp_screenshot_service.gd"
MCPInputService="*res://addons/godot_mcp/mcp_input_service.gd"
MCPGameInspector="*res://addons/godot_mcp/mcp_game_inspector_service.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")
```

Godot or addon settings changes can write local integration entries back into `project.godot`. Before committing, keep those entries in `override.cfg` so a clean clone does not reference absent addon files.

## Use Godot MCP Pro

The user explicitly requested MCP Pro. Its bundled CLI bridges this session to the enabled editor addon. Server installation on this machine:

```powershell
$mcpCli = 'C:\Users\Wynter\Downloads\godot-mcp-pro-v1.17.1\server\build\cli.js'
node $mcpCli project info
node $mcpCli scene open --path res://scenes/main.tscn
node $mcpCli scene play
node $mcpCli editor errors
node $mcpCli runtime exec --help
node $mcpCli scene stop
```

The editor must be running with the addon enabled. The CLI listens temporarily on a local port in 6510–6514 and waits for the editor connection. The server's production dependencies were installed with `npm ci --omit=dev --ignore-scripts`. Do not terminate unrelated Node/Godot processes to resolve connection issues.

For screenshots, consume `image_base64` into a PNG file; do not print the image payload to the console. Runtime script inspection can access `get_tree().current_scene`. Inspect connection/project identity before changing the editor. Keep game changes in source, not only runtime memory.

## Mechanics invariants

1. Keep the player's foot, local up and heading relative to their support. Camera mode cannot change puzzle state.
2. Six continuous faces of a traversable solid share one traversal rule. Never forbid the underside to repair a puzzle shortcut.
3. Surface changes require a continuous edge or a genuinely touching, compatible surface. No nearest-object magnetism or gap jumping.
4. Pause movement during transformation. Evaluate connections only after settling.
5. Check transformations for a safe attached-body sweep. Reject with an explanation instead of silently ignoring input.
6. Impossible adjacency belongs to authored configuration, not current camera alignment. An active opening must work in first person.
7. Map contact position, heading and local up through the same endpoint frame used for destination rendering. The current single pair uses translation; generalize explicitly before adding rotated pairs.
8. Undo restores a complete safe snapshot. Save only at settled checkpoints.
9. Keep fixed reference volumes, disconnected goals and distant decorative scenery separate from manipulable pieces.
10. Test all faces for alternate routes. A goal on another face of the same free-walking solid is not a route puzzle.

## Level and content workflow

The current opening, **The Other Ground**, is implemented. Arrival `(-16,2,0)` with size `(8,6,8)`, causeway `(-9,0.4,0)` with size `(6,2.8,2.2)`, and the carrier share bottom y=-1 but no top/side walking plane. The supported surface-seam rules require boarding along the underside. Covered internal joins reject body penetration. Discovery flags only drive feedback; never use them as invisible movement gates. If implementing general concave transfers later, audit this layout again for top-side bypasses.

F toggles upper/lower inspection without modifying puzzle state. Tab chooses the lower inspection when world up points down. First carrier boarding saves a checkpoint. Save version 2 prevents loading old arrival coordinates into the new geometry. Surface-change signals must fire after the complete foot/normal/heading update.

- Prototype continuous geometry first, then physical reconfiguration, then impossible adjacency.
- Use “observe, reconfigure, enter, reposition, reconfigure again, traverse, discover” as the loop.
- In each substantial puzzle, identify the necessary player position before a transformation.
- The Other Ground teaches undersides; The Passenger teaches boarding before rotation; The Distant Arch teaches persistent impossible adjacency; The Return Route later combines spatial memory and interior routes.
- Build hand-authored connected arrival spaces, moving courtyards, linked chambers and larger compositions. The finale should combine learned rules.
- Keep story environmental: drifting adjacency, beautiful intact architecture, distant light, temporary configurations. No universal repaired arrangement is required.
- Use optional routes for useful views, discoveries and additional puzzles; avoid currency gates and arbitrary dead ends.

## Presentation and accessibility

- Third-person camera roll follows world up, not surface up; only the character follows local gravity. Mouse orbits, and distance is adjustable. Preserve camera collision after positional smoothing, not just at the desired endpoint.
- New movement is screen-relative. While an unchanged key direction is held, preserve its transported tangent through edge turns; reprojecting every frame can send the player back across the same edge. A new input or intentional orbit reestablishes camera-relative movement.
- Third-person camera switches use cuts to avoid long fly-throughs. First person retains optional smooth transitions. Neither mode is assumed universally comfortable.

- Large abstract but inhabitable forms, deep blue/violet atmosphere, ivory light, selective warm accents. No RGB axis legend.
- Prioritize landmarks that remain recognizable after rotation; add bevels, surface detail, translucent elements and metal only where they improve scale/readability.
- Keep first-person UI quiet; overview exposes only selection, valid movement and essential prompts. No default solution line.
- Sound reinforces footsteps, joints and settling; visual feedback must carry all essential information too.
- Retain adjustable sensitivity, reduced motion, checkpoint recovery, undo and escalating hints. Test comfort with players rather than equating smooth animation with comfort.
- No jumping, combat, time pressure, lives, inventory or unrelated mechanics by default.

## Verification

Run this integration smoke test after changing traversal, adjacency, snapshots or crossing:

```powershell
& 'C:\Users\Wynter\Downloads\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe' --headless --path 'E:\Godot Games\spacial_puzzleGame' --quit-after 120 -- --self-test
```

It walks the opening from the real spawn, probes top/side/underside entry boundaries, tests covered solid joins, the first boarding checkpoint, underside carrier travel, courtyard reorientation, undo after disembarking, camera-state independence, gap isolation and impossible crossing. Follow-camera checks cover horizon, screen-relative controls on six faces, held input around edges, camera obstruction and first/third-person switching. It must print `SELF TEST PASS` and exit 0. Test mode does not write player progress.

Then use MCP Pro to run the game and inspect screenshots and errors. Check both modes, HUD at the target size, pause/rebind, carrier A/B, visible avatar, arch activation, destination preview, crossing and completion. Ensure no false connection appears mid-animation. Test side-face turns and corner approach diagonals when changing the walker.

## Scope honesty and documentation

Keep `spec.md` and this guide synchronized. Distinguish implemented mechanics from proposed campaign features. The current build is a compact mechanical prototype, not the complete campaign. Record limitations in concave surfaces, decorative collision, portal presentation and remapping instead of claiming unsupported behaviour. Preserve the source concept in full.
