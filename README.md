# Elsewhere

**Where do I need to be before I change the space?**

A first-person architectural puzzle adventure. Explore small monumental sci-fi structures in first person, then pull back into an isometric view to reshape them. Gravity follows authored paths around walls and undersides; if you stand on a structure while it turns, it carries you.

![Elsewhere concept board](docs/concept/elsewhere-concept-board.png)

*Concept board: a mood reference, not a final look.*

## Status

Pre-production, Phase 1 (prove puzzle depth). The playable content is one blockout monument, **The Ring**, built with the scene-authoring foundation. Prototype monuments are archived in `legacy/`.

## Run

Open `project.godot` in **Godot 4.7** and press **F5** to play The Ring. Press Escape for comfort settings and, as more are built, other monuments.

| Action | Default |
|---|---|
| Walk / look | WASD / mouse |
| First person ↔ isometric | Tab |
| Interact | F |
| Select structure (isometric) | Click it (1–9 also work) |
| Rotate structure | Q / E |
| Zoom isometric view (limited) | Mouse wheel |
| Reset zoom | Home |
| Undo / restart | Z / R |
| Checkpoint / hint | Backspace / H |
| Debug info / menu | F3 / Escape |

## Project layout

```
core/          traversal on authored surfaces and gravity curves
authoring/     scene components (paths, curves, sockets, rotators, markers) and validation
runtime/       generic runtime, the monument runtime and the HUD
monuments/     one scene per monument
tests/         headless self-test
addons/elsewhere_authoring/   editor dock: state preview, validation, Play From Here
docs/          spec, development guide, authoring reference, concept art
legacy/        archived prototype (read-only; ignored by Godot)
```

## Docs

- [Specification](docs/spec.md): design authority
- [Development guide](docs/skill.md): layout, invariants, workflow, verification
- [Authoring reference](docs/authoring.md): building a monument in the editor
- [Authoring friction log](docs/authoring-friction.md)
- [Legacy prototype](legacy/README.md): the last runnable version is the `prototype-final` tag

The Godot MCP Pro addon, credentials and machine-specific configuration are local only and excluded from Git. A fresh clone needs no addon to play.
