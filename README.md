# Elsewhere

A playable Godot prototype of the supplied spatial puzzle adventure concept.

Open **project.godot** in Godot 4.6 and press **F5**. Starts in architectural view. Press **Tab** to enter the world; walk with **WASD**, look with the mouse. In overview, select the carrier or arch with **1 / 2** or a click, and rotate with **Q / E**. **Z** undoes a transformation, **R** restores the checkpoint, **H** gives a hint, and **Escape** opens settings.

Board the carrier before turning it. Reach the violet courtyard, align the arch, and walk through to the distant light. Every face of the main blocks is walkable.

- [Game specification and full feature status](docs/spec.md)
- [Project development guide / skill.md](docs/skill.md)
- [Unabridged source concept](docs/original-concept.md)

Gameplay uses procedural geometry and sound; no external assets or addons are required to run a fresh clone. This is one compact courtyard prototype, not the full proposed campaign.

Godot MCP Pro 1.17.1 was used for development and validation. Its proprietary addon and machine-specific configuration are excluded from this repository. If you own MCP Pro, install it locally under `addons/godot_mcp/`; keep its autoload/plugin settings in the ignored `override.cfg`. See [the development guide](docs/skill.md) for connection details.
