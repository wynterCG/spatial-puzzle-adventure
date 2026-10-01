# SPEC — Elsewhere Level Authoring System
**Status:** Design / Pre-production
**Purpose:** Define how *Elsewhere* levels should be authored before committing to a full level editor or a rigid modular environment kit.

---

## 1. Goal

Build a level-authoring workflow that allows *Elsewhere* to produce compact, visually distinctive spatial puzzles efficiently without forcing every monument to be constructed from the same set of visual tiles.

The system should prioritize:

- reusable **gameplay behaviours**,
- authored and potentially unique **architectural forms**,
- fast puzzle iteration,
- clear visualization of paths, gravity, connections, and transformation states,
- and gradual development of editor tooling based on real production needs.

The system must not assume the final level-design grammar before enough puzzles have been created to reveal it.

---

# 2. Core Principle

> **Modularize puzzle behaviour before modularizing architecture.**

Two monuments may look completely different while sharing the same underlying systems.

For example:

```text
Turning Frame
    Custom Mesh
    Walkable Paths
    Gravity Transitions
    Connection Sockets
    Rotatable Structure
    Rotation States
```

and:

```text
Celestial Ring
    Completely Different Custom Mesh
    Walkable Paths
    Gravity Transitions
    Connection Sockets
    Rotatable Structure
    Rotation States
```

The authoring system should understand the behaviours and relationships.

It does **not** need to understand that one object is a "Turning Frame" and another is a "Celestial Ring."

---

# 3. Production Strategy

Development follows this sequence:

```text
Hand-authored puzzles
        ↓
Repeated design patterns
        ↓
Reusable gameplay components
        ↓
Authoring helpers
        ↓
Level editor
        ↓
Production asset library
```

Do not build the complete editor first.

The first 3–5 meaningful puzzles should remain relatively freeform so that the real design language of *Elsewhere* can emerge.

Whenever an authoring task begins repeating consistently, it becomes a candidate for tooling.

---

# 4. Current Level Design Philosophy

Each level should ideally be a **compact architectural monument**, rather than a chain of unrelated platforms.

The architecture itself should:

- establish the level's visual identity,
- contain the traversable paths,
- create the puzzle relationships,
- provide recognizable landmarks,
- and transform during play.

A level should not feel like:

> Platform → mechanism → platform → mechanism → goal.

Instead, the player should gradually understand and manipulate **one coherent spatial composition**.

---

# 5. Gameplay Authoring Components

These are candidates for reusable systems regardless of visual style.

## 5.1 Walkable Path

Defines where the player is allowed to move.

Required data:

```text
WalkablePath
- Path geometry
- Width
- Ground orientation
- Owning structure
- Entry sockets
- Exit sockets
- Active / inactive state
```

The rendered architecture and the logical path do not necessarily need to be the same object.

The gameplay path may exist as authoring data attached to custom architectural geometry.

---

# 5.2 Gravity Transition

Allows the player to move continuously between differently oriented surfaces.

Examples:

- floor → wall,
- wall → ceiling,
- 90° curved transition,
- 180° curved transition.

Required data:

```text
GravityTransition
- Start orientation
- End orientation
- Transition curve
- Travel direction
- Width
- Connected paths
```

Gravity changes must be deterministic and authored.

Ordinary edges remain blocking unless explicitly connected through a valid transition.

---

# 5.3 Connection Socket

Defines compatible connection points between structures.

Each socket should contain more information than position alone.

```text
ConnectionSocket
- Position
- Travel direction
- Ground normal
- Width
- Socket type
- Owning structure
- Connected socket
- Active state
```

Two sockets are compatible when their positional and orientation requirements match within authored tolerances.

Eventually, editor tools may snap compatible sockets together automatically.

---

# 5.4 Rotatable Structure

Reusable behaviour for architecture that can change orientation.

```text
RotatableStructure
- Pivot
- Allowed states
- Current state
- Transition duration
- Attached player behaviour
- Attached paths
- Attached sockets
- Collision requirements
```

Rotation should normally happen between **authored discrete states**, rather than unrestricted arbitrary rotation.

Example:

```text
State 0 = 0°
State 1 = 90°
State 2 = 180°
State 3 = 270°
```

Not every structure needs four states.

A piece may have only two valid configurations.

---

# 5.5 Player Carrier

A rotatable or movable structure may carry the player.

When carried:

- the player's local position relative to the structure is preserved,
- the player's current supporting surface remains meaningful,
- gravity follows the resulting ground orientation,
- and the player resumes movement from the transformed state.

The player is not teleported after the transformation.

---

# 5.6 Interaction

Reusable system for world interactions such as:

- levers,
- locks,
- brakes,
- switches,
- activation points.

Interactions should change meaningful puzzle state rather than exist simply to lengthen traversal.

```text
Interaction
- Activation type
- Target
- Persistent state
- Required conditions
- Feedback
```

---

# 5.7 Player Start

Defines:

```text
PlayerStart
- Position
- Forward direction
- Ground normal
- Starting path
```

The player must start with a valid gravity reference.

---

# 5.8 Goal

Defines level completion.

```text
Goal
- Trigger area
- Visual identity
- Completion event
```

Goals should preferably also function as recognizable architectural landmarks.

---

# 5.9 Checkpoint

Stores a valid puzzle state.

A checkpoint may need to preserve:

```text
- Player position
- Player orientation
- Current ground
- Structure states
- Interaction states
```

---

# 6. Transformation State System

Each transformable structure should expose its legal states explicitly.

Example:

```text
TurningFrame

State_A
rotation = 0°
connections:
    Socket_1 → Entrance

State_B
rotation = 90°
connections:
    Socket_2 → UpperGallery

State_C
rotation = 180°
connections:
    Socket_3 → GoalSide
```

The system should update connections only after the structure reaches a valid settled state.

Intermediate animation positions should not accidentally create temporary connections.

---

# 7. Puzzle State

A puzzle is not defined only by the orientation of its structures.

Its meaningful state consists of:

```text
Puzzle State =
    Structure configurations
    + Active connections
    + Interaction states
    + Player position
    + Player occupied path / surface
```

This is essential to the core design of *Elsewhere*.

Two identical architectural configurations can produce different gameplay situations if the player occupies different paths.

---

# 8. Puzzle Design Requirement

The system should support puzzles where:

> **The correct architectural configuration is not sufficient; the player must also be correctly positioned before creating it.**

Example:

The Turning Frame has:

```text
Outer Path
Inner Path
```

State A allows access to the Outer Path.

State B connects the Inner Path to the goal.

Simply rotating to State B therefore does not solve the puzzle if the player is still on the Outer Path.

The player must understand:

```text
Reach correct path
→ reposition
→ transform structure
→ use resulting connection
```

This is preferable to repeated:

```text
Board
→ rotate
→ leave
→ repeat
```

---

# 9. Architectural Authoring

Architectural geometry should remain relatively freeform during early production.

The system must support:

### Unique hero geometry

A monument can use a mesh created specifically for that puzzle.

### Reusable architectural pieces

Useful recurring elements may eventually include:

```text
Beam
Arch
Column
Support
Gallery
Trim
Platform
Joint
```

However, they should emerge from production experience rather than being defined prematurely.

*Elsewhere* should not require every monument to be assembled from an obvious grid-based tile kit.

---

# 10. Initial Blockout Library

A very small temporary library is sufficient during the current phase.

## Gameplay

```text
WalkablePath
GravityCurve90
GravityCurve180
ConnectionSocket
RotatableStructure
Interaction
PlayerStart
Goal
Checkpoint
```

## Blockout Geometry

```text
Beam
Platform
Frame
Wall
Arch
Column
```

These assets exist to accelerate experimentation.

They are **not the final visual library**.

---

# 11. Tool Development Phases

## Phase 0 — Current

Use existing Godot editing tools and custom scenes.

Create approximately 3–5 meaningful puzzle monuments.

Focus on discovering recurring workflows.

No dedicated Elsewhere Level Editor is required.

---

# 12. Phase 1 — Small Authoring Helpers

Build only tools that solve repeated friction.

Priority candidates:

### Connection Visualization

Display sockets and connection direction in the editor.

Possible representation:

```text
Green = connected
Yellow = compatible but disconnected
Red = invalid
```

Exact colours are implementation details and not locked.

### Ground Visualization

Show the intended ground normal for:

- paths,
- sockets,
- player starts,
- gravity transitions.

### Rotation State Preview

Allow the developer to select:

```text
Preview State 0
Preview State 1
Preview State 2
```

without running the game.

### Play From Here

Select a valid path or marker and launch directly from that location using its correct gravity orientation.

This is likely to become one of the highest-value iteration tools.

---

# 13. Phase 2 — Puzzle Authoring Tools

Only build this phase after several levels establish the actual workflow.

Potential features:

## Socket Snapping

Drag a structure near another connection.

Compatible sockets automatically align:

- position,
- travel direction,
- ground orientation.

---

## Show Active Connections

For the current configuration, visually display which routes are currently connected.

---

## Show Reachable Paths

Starting from the player's current authored location:

```text
Calculate connected traversal graph
→ highlight reachable paths
```

This does not need to solve the puzzle.

It only helps the designer inspect the current state.

---

## Rotation Sweep Visualization

Show the volume occupied by a structure while transitioning between states.

Useful for identifying:

- collisions,
- architectural interference,
- unsafe player positions.

---

## Puzzle State Snapshots

Allow designers to save temporary states such as:

```text
Initial
PlayerInsideFrame
PreGoal
Debug_State_03
```

and restore them quickly.

These are authoring tools, not necessarily player-facing save states.

---

# 14. Phase 3 — Production Level Editor

Only begin this phase when the puzzle grammar is stable.

Potential final toolset:

```text
Module placement
Socket snapping
Custom architectural mesh support
Path authoring
Gravity transition authoring
Structure state authoring
State preview
Connection validation
Reachability visualization
Play From Here
Puzzle snapshots
Interaction linking
Start / goal validation
```

The production editor should accelerate the established workflow.

It should **not dictate how puzzles must be designed.**

---

# 15. Validation

The editor may eventually detect common authoring problems.

Examples:

```text
Disconnected socket
Invalid path orientation
Player start without valid ground
Goal with no authored path access
Rotation intersects static architecture
Transformable structure has no valid state
Path terminates without connection
```

Later, graph-based validation may identify whether some configurations produce reachable routes.

This is not the same as automatically solving the puzzle.

---

# 16. What the Editor Should Not Become

The editor should not initially attempt to provide:

- general-purpose mesh modelling,
- arbitrary CSG architecture creation,
- Blender-like editing,
- procedural puzzle generation,
- automatic puzzle solving,
- automatic "fun" validation,
- a player-facing level editor,
- Steam Workshop integration,
- arbitrary physics construction.

These features dramatically expand scope without proving that they improve level production.

---

# 17. Player-Facing Level Editor

A public level editor is explicitly **out of scope for the current production plan**.

A player-facing editor would additionally require:

- complete editor UI,
- tutorials,
- safe object placement,
- robust undo/redo,
- file serialization,
- version migration,
- level validation,
- content limits,
- sharing/discovery,
- possibly moderation.

This should be considered a separate feature or project milestone if pursued later.

---

# 18. Art and Gameplay Separation

The authoring architecture should allow this:

```text
Gameplay logic
        ↓
Paths / sockets / states / interactions
        ↓
Attached to
        ↓
Custom monument geometry
```

Rather than:

```text
Fixed visual tile
        =
Fixed gameplay behaviour
```

This separation allows levels to remain visually distinctive while sharing reliable puzzle systems.

---

# 19. Development Rule

Whenever a task is repeated during level creation, ask:

> **Is this repetition part of designing the puzzle, or is it editor friction?**

If it is puzzle design, keep it manual.

If it is editor friction and occurs repeatedly across levels, consider tooling it.

Examples:

**Good manual work**
- deciding where a path should go,
- choosing the monument silhouette,
- deciding what a rotation should accomplish.

**Good automation candidate**
- aligning sockets,
- visualizing gravity normals,
- repeatedly setting the same debugging start position,
- manually switching structure states to inspect them.

---

# 20. Immediate Plan

### Step 1
Continue developing the Turning Frame monument.

### Step 2
Create 2–3 additional compact puzzles with intentionally different architecture and spatial ideas.

### Step 3
During development, record repeated authoring tasks.

### Step 4
Extract recurring **gameplay behaviours** into reusable components.

### Step 5
Create only the highest-value editor helpers.

Likely first priorities:

```text
1. Rotation State Preview
2. Connection Visualization
3. Ground / Path Visualization
4. Play From Here
5. Socket Snapping
```

### Step 6
After roughly 3–5 successful puzzle monuments, review them together and identify the real construction grammar of *Elsewhere*.

Only then define the mature module library and production editor.

---

# Success Criteria

The authoring system is successful when a new *Elsewhere* puzzle can primarily be created by:

> **Designing an interesting monument, assigning existing gameplay behaviours, defining its meaningful configurations and connections, and iterating quickly—without writing bespoke gameplay code for every level.**

The goal is **not** to make every level from the same modules.

The goal is to make **different architecture obey the same reliable spatial language**.