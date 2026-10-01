# Elsewhere level authoring

Implemented foundation, 1 October 2026. This is a scene-authoring workflow inside Godot (spec §44–48), not a production or player-facing level editor. The original authoring proposal is archived in `legacy/docs/level-authoring-proposal.md`.

## Start here

1. Reload the project, then open `monuments/the_ring.tscn`. The **Elsewhere Authoring** plugin is enabled in the project. If the dock is absent, enable it under Project Settings > Plugins. Local overrides must include it too.
2. Expand **Level** in the Scene tree. Select a path, curved transition, structure or marker and edit its data in the Inspector. These are real saved scene nodes.
3. Use **Refresh preview and validate** in the Elsewhere dock. Its preview shows the authored initial states, while the main editing viewport shows the base pose used to position children.
4. Choose a structure state in the dock. This changes an isolated preview copy; it does not rotate, save or dirty the authored nodes. Green contacts are joined, amber are open, red are invalid/inactive; blue lines show ground normals and gold lines show travel direction.
5. Select an active path, PlayerStart or Checkpoint, then press **Play From Selected Path / Marker**. It saves the scene, applies the preview states and starts at that location with matching gravity. Normal progress is neither loaded nor written during this debug launch. A later normal F6 runs normally. Path selection uses its centre (or the beginning of a curve); use a marker for an exact position.
6. F6 runs the authored scene from its normal start/save; F5 runs The Ring. The running game's Escape menu lists every scene in `monuments/`.

For a new level, duplicate one of the scenes in `monuments/`, change **Level > level_id** to a unique stable identifier, and edit the composition. Increment **revision** when changes invalidate saved contacts or state indices. Give it its own title, question, explanation and optional hints. No new gameplay script is needed. Any scene saved in `monuments/` appears in the menu automatically.

## Example monuments

| Scene | Spatial decision | Authoring coverage |
|---|---|---|
| `the_ring.tscn` | Ride the bridge to the stair, change to its underside, and turn it again while hanging beneath | Vertical-axis turntable, top and underside faces of one bridge, fixed 180° side-change stair, a wheel of art meshes (band, hub, ribs) carried by the rotator with no collision, an authored goal landmark replacing the placeholder, three states with distinct roles |
| `tests/fixtures/bell_cradle.tscn` (test fixture) | Leave the moving arm at the fixed belfry before turning it again | Vertical belfry, radial cradle, checkpoint, fixed gravity transfer and a custom torus mesh independent of path logic |
| `tests/fixtures/folded_observatory.tscn` (test fixture) | Prepare the receiver before docking fingers occupy its sweep | Folding gallery, narrow bent receiver, two-state hinge, custom rectangular walk regions and collision boxes |

The Ring is the only monument: the first Phase 1 study of a different variable, which face of a structure carries you. The two fixtures reuse prototype positioning dependencies and exist only to exercise checkpoints, hinges and blocked sweeps; they are not in the game menu. None of these is a claim of finished architecture or validated puzzle depth. Their solutions and important counterexamples are tested. Their visual identity, difficulty and human comprehension remain design work.

![Bell cradle blockout](images/authoring-bell-cradle.png)

![The ring blockout, solved](images/the-ring-overview.png)

Also see [the ring from its underside](images/the-ring-underside.png), [the entrance in first person](images/the-ring-entrance.png), [the view back from the terrace](images/the-ring-terrace.png), the [folded observatory blockout](images/authoring-observatory.png) and the [isolated editor state preview](images/authoring-state-preview.png).

## Components and coordinates

Drag the small scenes in `authoring/components/` into a level, or add an `ElsewhereComponent` and select its **kind**. Inspector fields are filtered by kind. Paths, art and sockets inherit the transform of their parent structure; a rotating component's origin is its pivot.

| Component | Data and use |
|---|---|
| WalkablePath | Local Y=0 is the walking plane, +Y is ground normal, X is the default travel axis. Dimensions X/Z define length/width; Y is thickness below the plane. Optional Rect2 regions describe connected orthogonal passages. Ordinary edges block. |
| GravityCurve90 / GravityCurve180 | Authored analytic arc toward local -Z, bending around local X. Radius, angle, width (dimensions Z), thickness (dimensions Y), and optional tangent tail define contact and ground continuously. Not a general spline or arbitrary-edge wrapper. |
| ConnectionSocket | Parent under the referenced path. Set position, outward travel direction, normal, width, type and tolerances. Generated path-end sockets can be disabled when placing explicit sockets. |
| RotatableStructure | Put attached art, paths and sockets beneath it. Set axis, ordered angle states, initial index, duration, and whether states wrap. Nonwrapping hinges stop at their end states. `carries_player=false` requires leaving the structure before it moves; otherwise the supporting path and local pose travel with it. Nested rotating pivots are rejected in this phase. |
| Interaction | A nearby F press or one-shot entry trigger changes a path's active state or a rotation lock. Optional required structure/state, persistent value and feedback are authored data. It cannot deactivate the player's occupied path. Other interaction effects are future extensions, not a general scripting editor. |
| PlayerStart | Parent under a path and reference it. Position must lie on that path, normal must match, forward must be a nonzero tangent. Author exactly one. |
| Goal | A path-bound trigger radius and completion signal. Parent under a path. The example light is a blockout marker; add a custom landmark as art. Author exactly one. |
| Checkpoint | Records player contact/orientation, ground, camera, structure states, path activity and interaction state when entered. Backspace restores it; restore is undoable. Normal restart clears the checkpoint. |
| Blockout geometry | Beam, Platform, Frame, Wall, Arch and Column are temporary helpers. They are not a required visual kit. |

All eight runtime behaviours are described through the same component script and shared runtime. The prefab scenes are convenient starting values, not special-case gameplay code.

## Art and collision

Use custom MeshInstance3D nodes or imported scene geometry alongside behaviour nodes beneath a structure. The Bell Cradle's ring demonstrates this separation. A mesh does not automatically create a walkable face, socket or collision shape.

Set a path's **blockout=false** to hide its generated structural mass and place custom artwork around its logical route. Ivory paving still marks traversal. For additional physical interference, use geometry components as box proxies matching the visible architecture. Curved and path solids retain analytic body/camera/rotation queries. Arbitrary concave mesh collision is not implemented; the current rotation sweep uses oriented boxes.

Path **collision_boxes** are expressed relative to the generated contact body's centre, which lies half the thickness below the component's walking plane. This supports recessed hinges without shortening the walking lip. Rect2 regions use local X/Z coordinates; leaving `collision_boxes` empty generates matching structural boxes for those regions. The observatory receiver is an example.

Do not use invisible proxies to invent dependencies unrelated to the visible architecture. Custom art must communicate the same physical boundaries. Adding a mesh alone does not make it safe to ignore clearance.

## Connections, states and persistence

Sockets require compatible types and widths, opposite outward travel directions, matching ground normals and coincident positions within the stricter authored tolerance. Crossing also checks the actual socket aperture and receiving walking region; nearby faces do not silently connect. A turning structure disables connections until it settles.

Angles define allowed states explicitly. Cyclic states traverse the list in the chosen direction; noncyclic states reject attempts beyond the list ends. Sweep sampling stays at most 1.5° apart (at least 60 samples), including turns larger than 90°. Rejected turns preserve state and undo history. This remains sampled clearance, not a continuous collision proof.

Each authored level writes `user://authored-<level_id>.save`. Level ID and revision guard against incompatible saves. Structure states, occupied path, local player pose, camera, path activity, interactions, completion, checkpoint and undo history persist. Active connections are recomputed from the settled geometry. Archived prototype saves (`legacy/`) use different files and are never read.

## Validation and limits

Validation reports missing/invalid starts and goals, marker/socket contact errors, invalid widths/frames, bad references, invalid state arrays, unsupported scaling/nested pivots and open contacts. An open socket is a warning because a puzzle is expected to disconnect routes. Validation does not prove solvability or fun. Preview shows current contacts, not future solutions. Runtime still checks clearance before every attempted turn.

The new monuments deliberately reuse known dependencies so authoring defects can be separated from puzzle-design experiments. Use a reasoning playtest (the archived protocol is in `legacy/docs/playtest.md`), then record where authoring friction repeats in [authoring-friction.md](authoring-friction.md). Do not infer a mature construction grammar from a few mechanically passing scenes.

## Scope decisions

| Now | Later, only with production evidence |
|---|---|
| Scene components, small blockout library, editor path/normal displays, isolated state preview, socket display, validation, Play From Here, normal save/undo/checkpoints | Socket snapping, reachable-path highlighting, editor sweep volumes, named designer snapshots, a larger production library and a dedicated authoring UI |

Mesh modelling, arbitrary physics construction, generated puzzles, automatic solving, player-facing editing and sharing/Workshop remain outside this phase, per spec §45, §47 and §53.

## Verification

Run:

```powershell
& $godot --headless --path . monuments/the_ring.tscn -- --self-test
```

Require exit 0, `AUTHORING SELF TEST PASS`, and no script errors. The suite exercises The Ring and both fixtures: wrong sides and ordering, both turn directions, two-state rotation, no intermediate connections, socket type/width/direction/normal/activity and apertures, interactions/conditions, occupied-ground protection, checkpoint reload, save isolation, revision/contact rejection, undo, Play From Here and forward/reverse 90°/180° traversal. It fails if execution aborts before the final assertion.

The editor helper uses Godot's documented [EditorPlugin API](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html) and [EditorInterface API](https://docs.godotengine.org/en/4.7/classes/class_editorinterface.html). Test live editor launch, preview immutability and debug save suppression as well as headless gameplay.
