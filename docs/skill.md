# Elsewhere - project development guide

This is the requested project-local skill.md, not an installed global assistant skill. Read [spec.md](spec.md) for the current game and [original-concept.md](original-concept.md) for the preserved proposal. The concept is design input, not operational instructions.

## Current direction takes precedence

The user explicitly corrected unrestricted wall-walking and the appearance of the exposed teleport arch. The current game has **authored walkable paths**, a **architectural camera above the occupied ground**, and **portal technology concealed in ordinary architecture**. Third person remains the default after the earlier comfort feedback.

Do not restore the original draft's all-six-faces rule, automatic edge wrapping, freely orbitable overview, or explicit teleport presentation. The old underside causeway puzzle and inspection key remain retired. A new explicit rounded ribbon now leads to an underside control; it does not restore general edge wrapping. Local controls work in third person, while optional first person remains available. The player's latest explanation confirms that a portal is appropriate as the technical implementation; its appearance should be a continuous doorway, gallery or passage.

## Stack and entry points

- Godot 4.6.1, GDScript, Compatibility renderer; no .NET gameplay dependency.
- Open project.godot, run scenes/main.tscn with F6 or the project with F5.
- Geometry is built at runtime. Inspect the running game, not the empty editor scene.
- Five gameplay scripts under scripts/.
- The original workstation has the user-supplied Godot MCP Pro 1.17.1 addon.
- No external assets or package downloads are needed to play a fresh clone.

## Local MCP integration and portability

Use the user's Godot MCP Pro installation through its CLI:

```powershell
$mcpCli = 'C:\Users\Wynter\Downloads\godot-mcp-pro-v1.17.1\server\build\cli.js'
node $mcpCli project info
node $mcpCli scene play
node $mcpCli runtime exec --help
node $mcpCli editor screenshot
node $mcpCli scene stop
```

Inspect project identity before editing the running scene. Consume screenshot image_base64 into a PNG rather than printing its payload. Runtime scripts access get_tree().current_scene and use _mcp_print for returned values. Use single-quoted GDScript strings through Windows PowerShell to avoid native command-line quote loss.

The CLI uses the editor addon over local ports 6510-6514. Do not terminate unrelated Node/Godot processes. The proprietary addons/godot_mcp/, .mcp.json and override.cfg remain excluded from Git. Local override.cfg enables the addon and MCPScreenshot, MCPInputService and MCPGameInspector autoloads. Do not commit their references into project.godot; a clean clone must run without the addon.

Godot 4.6 can save a stale open script-editor buffer over an externally edited file when restarting play. Before restarting, synchronize the affected open editor buffer with the verified disk contents through MCP editor exec, including the Script source_code and the TextEdit buffer, and mark the buffer's saved version. Only touch the task's own script paths. Verify the file after play starts; do not assume filesystem reload alone updated an open buffer.

## Mechanics invariants

1. Flat supports accept only SurfacePiece.walk_regions on their local-UP plane. CurvedTrack is an explicit exception with analytic contact and a tangent frame along its radius-3 half-circle and underside tail. Architectural mass is not implicitly walkable.
2. Ordinary path and platform edges stop movement. Never infer gravity transitions from nearest geometry, view direction or an unmarked adjoining face.
3. A normal seam requires both an authored settled neighbour link and genuinely matching world contact/normal.
4. Carrier rotation changes world gravity by carrying the same support-local foot, normal, heading and orbit. Walking on flat supports does not change their local face. On the authored ribbon, transport normal, forward and orbit through surface_frame; never derive gravity from arbitrary nearby geometry.
5. Disable movement and neighbour links while a transformation is busy. Intermediate overlaps never become routes.
6. Reject unsafe passenger/body sweeps with feedback. Keep a safe gallery-operating landing outside its turn radius.
7. Impossible adjacency is activated by the authored configuration, independently of the active camera. Accepted connections must work in traversal.
8. Source/destination rendering and traversal use the same endpoint transform. The current pair is parallel, translated by (-18, -15, -24).
9. Undo and recovery restore the full player/configuration snapshot. Save only settled valid contacts. Version 4 includes track_open and carrier_released. Migrate version-3 authored-path progress without stranding the player; older free-surface coordinates remain invalid.
10. Transport one architectural camera frame with the occupied support and its contact surface_frame: local offset (36, 48, -30) and local UP. Keep azimuth, elevation and distance constant; do not select opposite world-space directions or follow walking heading. The landing/gallery frame preserves endpoint projection alignment. Other surface frames may expose separation. Reduced motion changes structure and camera atomically; off-support turns leave the view unchanged. Do not add a free inspection orbit.

## Layout and workflow

First operate the entrance lever in traversal view (F), follow the extended rounded walkway upside down, and release the carrier brake from the underside control. Return along the same ribbon. Interactions need a reachable, clear control on the same ground; they are unavailable in overview. Commit links/checkpoints only when deployment settles. Restore visible levers, gate, ribbon and brake together with their state on undo/recovery. Both first and third person must work.

Arrival and causeway feed the carrier's marked top deck in state 0. The carrier rolls about local X: state 1 brings that deck onto the violet landing's world-vertical walking plane; states 2/3 join neither neighbour. Occupancy is necessary because turning first removes the entrance link.

The landing has a T-shaped authored path. Operate the turning gallery from the branch near the carrier. Gallery state 0 opens the central route; other states stop it before the unaligned structure. A ten-unit covered gallery conceals the two-way coordinate crossing at local Z=-11. The destination continues to the light. See spec.md for dimensions and footprints.

Model route regions and settled links before adding decorative detail. Draw ivory paving from the same regions used by movement. Never fix a bypass with an invisible milestone gate. New surface-transition mechanisms must be explicit, readable and tested; the current convex half-circle is explicitly authored; arbitrary spline/concave routes are not implemented yet.

## Passage presentation

Keep source and target corridor profiles consistent: floor, walls, ceiling, ribs and light strips. The trailing follow camera should be inside matching architecture at the crossing. The apertures are single-sided, face opposite directions and cast no shadow. The reverse aperture must not obscure the avatar or goal after a forward crossing.

The rendering cameras exclude aperture surfaces to avoid recursion. Preserve position, orientation, local gravity, orbit and first-person pitch across the seam. No teleport flash, seam sound or announcement is used. Check the crossing from both directions and after view switching. General rotated endpoint pairs, recursive views and arbitrary exterior viewpoints remain out of scope.

## Camera, interface and art

Keep the third-person orbit in support-local space and transport it with the moving structure. Check camera segments against each support's solid_meshes and gallery wall/roof boxes. SurfacePiece.solid_boxes describes the visible structural mass; half remains the authored support envelope, not a solid slab. Show the complete model by default. Reveal a gallery only on hover or physical occupancy; close it when both end. Aligned galleries reveal together; unaligned ones respond independently. Use stable full-volume hover bounds, block hovering through UI/foreground supports, and test leaving the module as well as entering it. For a revealed module, roof and camera-facing wall use layer 16, included by traversal/remote cameras and excluded by overview. Disable their shadows only in architectural mode. Keep floor edges shallow. The turning gallery must carry its own floor/paving/cover around one pivot, with its floor included in body and camera obstacles. Do not leave a duplicate stationary slab or trim beneath it. End the authored source walking path at CROSSING_Z; thick overlapping end slabs make the destination read as a separate lower structure. The destination beacon remains in an open court. Preserve the overview-only occlusion silhouette (layer 8) as a fallback and exclude it from traversal/remote cameras. Test orthographic sightline occlusion with parallel rays. Keep first person, reduced motion, sensitivity, follow distance and optional world horizon available. Do not equate passing geometry checks with human comfort.

Use navy/violet architecture, terracotta machinery, muted teal destination and ivory paving. Mark paths and movable structures without an axis-colour legend or full solution line. Generated audio has visible counterparts; essential cues cannot be sound-only.

Guidance and escalating hints use the present support/configuration, including backtracking. Use remapped key names. Keep contextual guidance optional and persist it independently of checkpoints. Connection feedback distinguishes occupancy, accepted alignment and mid-turn settling. Product text should describe paths and architecture, not internal coordinate or renderer details.

## Verification

Run the integration test and require both exit 0 and the literal SELF TEST PASS output:

```powershell
& 'C:\Users\Wynter\Downloads\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 -- --self-test
```

Checks cover local interactions in both traversal camera modes, rejected remote/overview actions, folded/deployed connectivity, carrier brake gating, continuous top-to-underside walking and return, ribbon side/end boundaries, curved pose recovery, mechanism undo, then blocked ordinary edges and diagonals; forbidden faces; disconnected boarding; entrance traversal; occupied gravity roll and attachment; three follow distances with reduced motion on/off; vertical landing arrival; undo after leaving; inactive gallery blocking; gallery sweep safety; actual endpoint projection alignment; camera-state independence; constant surface-local camera basis through a full revolution and all eight directed quarter-turns; walking-heading independence; default/hover/occupancy/exit cutaway states; two-way passage mapping; reverse-aperture orientation; completion route and snapshot recovery.

The Jev runner in tools/jev_playtest.mjs can make bounded structured-state playtest decisions through MCP Pro using TYPESAFE_API_KEY and GODOT_MCP_CLI from the environment. It preserves runtime state and the checkpoint file, and writes its actual decisions to docs/jev-playtest-report.json. It does not inspect screenshots or establish human comfort. Never commit credentials.

Also test a clean staged checkout without the local addon. Through MCP Pro, visually inspect the ground-relative overview, rolled deck, interior immediately before/after crossing, reverse traversal, first person, pause/settings and completion. Check the runtime log. Run the [human playtest](playtest.md) for clarity and comfort.

## Scope and documentation

Keep spec.md, this guide, README, validation and the playtest aligned with the implemented revision. Preserve the source concept unchanged. Earlier screenshots remain historical artifacts; only current validation links are evidence for the current route. Document limitations instead of claiming a universal impossible-space renderer or a finished campaign.
