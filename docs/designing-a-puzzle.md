# Designing a puzzle

> **Components describe what architecture can do. Geometry describes what architecture is. You design the puzzle by combining the two.**

This is the procedure for designing an Elsewhere monument by hand, in the Godot editor. The toolkit (the components, the dock, the tests) carries the engineering. The spatial idea is yours: "if I go in here, turn this, notice that, then come back underneath…" never comes from a generator.

The place comes early, and the final art comes last. The Threshold and The Spillway showed why: a puzzle can be logically valid and still feel like a puzzle for its own sake. Architectural meaning has to grow together with the mechanics, in cheap blockout, long before modelling.

## The procedure

1. **Write the "aha" in one sentence.** What does the player need to realise? *"I need to get underneath the bridge before moving it."* If you can't write it, you don't have the puzzle yet.
2. **Write one sentence describing the place.** *"An abandoned flood-control gate whose maintenance deck rotates with the sluice."*
3. **Start, goal, and why the direct route is impossible.** The answer to "why can't I just walk there?" is the base of the puzzle.
4. **Block 3–5 major architectural masses.** No decoration. Use `authoring/templates/new_monument.tscn` (copy it into `monuments/` and give it its own `level_id`). Can you explain the spatial relationship by looking at the masses alone?
5. **Decide how the place's purpose supports the puzzle.** Why does this thing move? Why is that face walkable? Why is the goal there?
6. **Add behaviours.** Paths and curves where the player walks; sockets where paths meet; a **Transformable Structure** on whatever moves. Give its states descriptive names ("Docked West", "Raised", "Goal Alignment") so you can think "when the bridge is in Goal Alignment, its underside meets the gallery".
7. **Preview states and read the connections.** In the Elsewhere dock:
   - pick each structure's state;
   - read **Connections** (what joins now);
   - select a structure to see **what each of its states changes** (+ new, − removed, stranded paths); clicking a row previews it;
   - select a path and press **Show Reachable** to see where the player can walk right now.
8. **Play From Here and iterate.** Select a path or marker. Set the structures, interactions and link pair you want in the dock, then press **Play From Selected Path / Marker** to start exactly there. Move a gallery 8 m, preview again, play again.
9. **Readability pass,** without debug labels:
   - **Isometric:** can you identify the start, the goal and what moves? Can you read the large architectural idea? Can you tell what you don't understand yet?
   - **First person:** do the start and the goal have recognisable landmarks? Can you tell which surfaces are walkable? Can you recognise the major structures from inside? Upside down, is world-down obvious?
10. **Pin the solution in a test.** Add the monument to `tests/authoring_tests.gd`, or give it its own `tests/<name>_tests.gd`:
    - its solution played through the runtime;
    - the tempting wrong route and the way back;
    - its minimum with `tests/state_graph.gd` (`minimum`; pass a rotor list to show a structure is needed);
    - run the eye-clearance probe.
11. **Replace the blockout with authored architecture.** Keep the same components; only the geometry changes.

## Transformable Structures

One component (Inspector: *Transformable structure*) covers everything that moves: rings, bridges, gates, lifts.
- **Motion:**
  - **Rotate:** each state is an angle about `axis`;
  - **Slide:** each state is an offset from the authored pose, in the structure's own frame.
- **Cyclic states:** on, Q/E wrap round (a ring); off, they stop at the first and last state (a lift does not glide from High straight back to Low). Rotate starts cyclic and Slide starts non-cyclic.
- **State names:** optional, one per state; they show in the dock and in F3.
- **Carrying:** the player standing on it moves with it, whatever the motion.
- **Sweeps:** a move that would pass through fixed geometry is refused, with the blocker named.

## The library

Keep it small. Add a piece only when a puzzle you are designing needs it.

| Gameplay | Blockout |
|---|---|
| WalkablePath, GravityCurve90/180, ConnectionSocket, RotatableStructure (Transformable Structure), Lift, Interaction, SpatialThreshold (experimental), Goal, Checkpoint, PlayerStart, StateArt | Platform, Beam, Wall, Column, Frame, Arch, Ring |

**Blockout pieces are for testing a form quickly,** not the vocabulary puzzles are made of. Don't ask "what puzzle can I make from a Ring and a Lift?" Ask "I want an enormous counterweight; which shapes let me test it now?" Hero geometry later replaces them completely.
- **Ring:** a round wall of boxes with openings (`x` segment, `y` width, `z` bottom, `w` top). It rebuilds only its `GeneratedGeometry`; anything you add under it is kept. Walls that hide or reveal things must be boxes (Ring, Wall, `GEOMETRY`): line of sight and the eye check ignore CSG.
- **StateArt:** dressing shown only while a structure rests in its *Visible states*, e.g. indicator lights, open or closed shells, rails, water pouring through an open gate. It never changes what joins.
- **PathLamp** and **HangingPendant** are the two lamp languages:
  - a path lamp stands perpendicular to a walkable surface ("you can stand here");
  - a pendant always hangs toward true down ("this is which way the world is").

## A monument's layers

| Layer | What | Who cares |
|---|---|---|
| Hero architecture | custom geometry designed for this puzzle | the player's understanding |
| Gameplay layer | paths, curves, sockets, Transformable Structures, interactions, goal | the runtime and the tests |
| Dressing | the Elsewhere kit, kitbash assets, lamps, vegetation, water | atmosphere |

The toolkit never cares where a mesh came from (Blender, a purchased kit, your library). Only the gameplay layer decides what joins.

## Not yet

- No procedural puzzle generator.
- No automatic puzzle designer.
- No solver inside the editor.
- No universal snapping grid.
- No external level editor.
- No final modular kit.

The Python generators in `tools/` built the existing monuments and stay for them; new puzzles are authored in the editor.
