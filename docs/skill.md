# Elsewhere — development guide

How to work in this repository. The [spec](spec.md) owns every design decision; this guide owns layout, workflow, invariants and verification. When the two disagree, the spec wins and this guide gets fixed. Do not restate design here; point to spec sections.

## State of the project

The project restarted on 1 October 2026 from the ELSEWHERE spec. The earlier prototype (positioning studies, the connected courtyard chapter, the Lantern Fold, the procedural monument, the portal gallery, camera experiments and their docs) is archived read-only in `legacy/`. The last runnable prototype is the git tag `prototype-final`. Use the archive as reference; do not import from it, and do not revive its procedural layout builders.

Current phase: spec §54 **Phase 1 — Prove Puzzle Depth**. The only monument is The Ring v3 ([design](designs/2026-10-01-the-ring-v3.md)): two independent rotors around a hollow tower whose hidden interior changes the player's side, with first-person cues (guide line, east sightline slot). First person discovers why a configuration matters; isometric is an authored composition for acting on it. The authored Turning Frame conversion is archived in `legacy/monuments/`; spec §41–42 still names the Turning Frame as a design target, so a fresh version may return as a new monument. The next real work is new monuments with distinct spatial ideas (candidates: Appendix A of the spec), each tested against §16 and §51.

## Layout

| Folder | Responsibility |
|---|---|
| `core/` | Authored-surface traversal: `surface_piece.gd` (walk regions, contacts, solids; `class_name SurfacePiece`), `surface_walker.gd` (player, first-person camera; `SurfaceWalker`), `curved_track.gd` and `gravity_path.gd` (analytic gravity curves) |
| `authoring/` | Scene-level data: `component.gd` (`ElsewhereComponent`, every §46 behaviour selected by `kind`), `level.gd` (`ElsewhereLevel`), `connections.gd` (socket descriptors and compatibility), `validation.gd`; `components/*.tscn` are the drag-in §46 blockout pieces |
| `runtime/` | `architecture_runtime.gd`: generic runtime (camera B, turns and sweep clearance, snapshots/undo, input, preferences, save hooks). `monument.gd`: builds an `ElsewhereLevel` into a playable monument (paths, sockets, interactions, checkpoints, goal, per-level saves, Play From Here). `hud.gd`: minimal HUD |
| `monuments/` | One scene per monument: root `Puzzle` node with `runtime/monument.gd`, plus a `Level` child holding the authored data. Main scene: `the_ring.tscn`. Every scene here appears in the in-game menu |
| `tests/` | `authoring_tests.gd` (headless self-test, launched from The Ring), `test_helpers.gd`, `fixtures/` (Bell Cradle and Folded Observatory scenes kept only to cover checkpoints, two-state hinges and blocked sweeps; they are test data, not monuments) |
| `addons/elsewhere_authoring/` | First-party editor plugin: state preview, socket/normal display, validation, Play From Here (§48) |
| `docs/` | `spec.md`, this guide, `authoring.md` (component reference), `authoring-friction.md`, `concept/`, `images/`. Has a `.gdignore` |
| `legacy/` | Frozen archive with a `.gdignore`; Godot never loads it |

Turntable (vertical-axis) structures can dock with fixed architecture only through narrow radial bridges: a wide or tangential piece sweeps its corners through anything touching its edge. Keep docking widths around 1.6 m at radius ≥ 6 m, as in The Ring. Tests must finish tweens with `H.turn` (it steps the tween to completion), not a fixed time.

Spec-to-code map: §46 library → `authoring/components/`; §48 tools → the plugin; §50 data model → `ElsewhereLevel` + `ElsewhereComponent` tree; §12–14, §18–19 → `architecture_runtime.gd` + `monument.gd`; §9–11 → `update_camera` / `transport_ground` / `ElsewhereLevel.overview_local_offset()`. Minimum-solution guards → `tests/state_graph.gd`.

## Making a monument

1. Duplicate a scene in `monuments/`. Set a unique, stable `Level > level_id`; bump `revision` whenever saved contacts or state indices would become invalid.
2. Compose with components under rotators, following [authoring.md](authoring.md). A monument is **scene data**: no per-level script and no procedural builder. If a monument seems to need new code, extract a reusable behaviour into `ElsewhereComponent`/runtime only after it repeats (§45). Log the friction in [authoring-friction.md](authoring-friction.md).
3. Before building, write the §16 template (expected first idea / why insufficient / required discovery) into the level's `question`, `explanation` and `hints`.
4. Add the monument to `tests/authoring_tests.gd`: its solution, the tempting wrong route and recovery.
5. Judge the blockout visually (see below) in both views before calling it done.

## Visual rule

The [concept board](concept/elsewhere-concept-board.png) (spec Appendix A) sets the core aesthetic: big shapes, a clean silhouette, readable in the isometric view, one accent per monument, emissive lines that trace routes. Do not copy its forms literally. Even in blockout, compose one recognizable silhouette before adding detail, keep walkable surfaces visibly distinct from non-walkable mass (§7.2), and never use invisible restrictions on surfaces that look walkable. Colours carry mood, never XYZ axes or hidden rules.

## Mechanical invariants

These are proven behaviours; break them only with an explicit spec change.

1. **Authored contact only.** Only marked walk regions accept contact; ordinary edges block. Never infer gravity from proximity, camera direction or an unmarked face.
2. **Analytic curves.** Gravity curves are explicit arcs (90°/180°, optional tail) that transport normal, heading and orbit continuously. There is no general spline or arbitrary-edge wrapping.
3. **Sockets.** A link needs compatible type and width, opposite travel directions, matching normals, coincident positions within tolerance, an active path, and an actual crossing inside the socket aperture and receiving region. Never gate links with progress flags.
4. **Carried pose.** Moving supports preserve the player's support-local pose. Separate paths on one structure stay separate; never silently transfer the player to a more useful path.
5. **Turns.** Links are disabled while turning and only form at settled authored states. Every turn samples the sweep at ≤1.5° (minimum 60 samples) against other structures and player clearance. Construction tolerance is for docking edges, not for hiding overlaps. `carries_player=false` structures refuse to move while occupied.
6. **Rejected turns** change nothing: no state, no snapshot, no undo entry. Recovery by withdrawing or undoing must always be possible.
7. **Snapshots.** Undo, checkpoints and saves restore structure states, occupied path, local pose, both camera layers, path activity, locks and interactions. Saves are per level (`user://authored-<level_id>.save`) and guarded by level id + revision + contact validity.
8. **Camera B (§9–11).** Transport the previous camera frame by the shortest change in ground normal; never rebuild heading from support axes or inherit yaw about an unchanged normal (turntable turns do not orbit the view). The composition (focus, size, azimuth, elevation) is authored per monument and expressed in the ground frame; there is **no orbit layer**. Zoom stays within 0.8–1.25, Tab never resets it and Home resets only zoom. Character look never affects the isometric view.
11. **Diegetic selection.** The HUD never lists movable structures. In isometric the player points at a structure: `pick_rig` ray-tests only movable assemblies' own meshes (boxes exactly, rings as flat annuli), so static architecture never steals a click and hidden interiors are never pickable. Hover and selection draw an outline in the structure's own accent (rotator `tint`, `runtime/outline.gdshader`), never a fill that hides geometry, and only in isometric.
12. **Colour language.** An accent light means *this moves*, and each moving assembly has one accent (its rotator `tint`). Warm white is information and destination. Static architecture is neutral and never carries a mover's accent. Fix unreadable relationships with composition, fades or framing, not camera freedom.
9. **Controls.** On ordinary ground, fresh movement input follows the projected camera; transported controls apply only on the authored curve during a held gesture. Mouse look alone never turns the avatar.
10. **Play From Here** never loads or writes normal progress, and editor preview never mutates authored transforms.

## Verification

Godot 4.7.2 (Steam build, no console executable; capture output with `--log-file`):

```bash
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$G" --headless --path . --import --log-file import.log
"$G" --headless --path . monuments/the_ring.tscn --quit-after 600 --log-file test.log -- --self-test  # --quit-after stops a hang if a script fails to compile
```

Require exit 0, the literal `AUTHORING SELF TEST PASS` line and no `SCRIPT ERROR` in the log. Close the editor before moving or renaming files; an open editor can re-save stale buffers to old paths. For gameplay or visual changes, also check live (Godot MCP Pro below): walking, Tab, 1–9 selection, Q/E, Z, wheel/Home zoom, upside-down traversal, the finish panel, and the editor dock (preview immutability, Play From Here). When a monument's solution is settled, pin its minimum with `tests/state_graph.gd` (turns and actions) so a socket or geometry change cannot add a shortcut. Tests prove mechanics, not comprehension; do not claim players understand a puzzle until an unaided playtest shows it (§51).

## Godot MCP Pro

```powershell
$mcpCli = 'C:\Users\Wynter\Downloads\godot-mcp-pro-v1.17.1\server\build\cli.js'
node $mcpCli project info      # verify this is the Elsewhere project first
node $mcpCli scene play
node $mcpCli runtime exec --help
```

Runtime scripts use `get_tree().current_scene` and `_mcp_print`. Use single-quoted GDScript strings through PowerShell. Decode `image_base64` to a file; never print the payload. Stop only this project's play session. Before restarting play after external edits, make sure the editor's open script buffers match the disk.

## Repository rules

- The proprietary `addons/godot_mcp/`, `.mcp.json` and `override.cfg` stay untracked; do not add references to them in tracked files. Credentials never enter Git.
- `addons/elsewhere_authoring/` is first-party and tracked.
- Keep the spec, this guide, `authoring.md` and the README aligned when behaviour changes. Update spec Appendix B when a spec system changes status.
- Commit or push only on request; branch from the current feature branch, and do not merge to `main` without a request.
