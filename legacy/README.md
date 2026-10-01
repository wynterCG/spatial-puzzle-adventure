# Legacy prototype archive

This folder is a read-only archive of the Elsewhere prototype, as it was before the project restarted from the [new spec](../docs/spec.md) on 1 October 2026. A `.gdignore` file keeps Godot from loading anything here, so these scripts and scenes do **not** run from this folder.

To run the prototype, check out the tag:

```bash
git checkout prototype-final
```

## Contents

| Path | What it was |
|---|---|
| `scripts/positioning_game.gd`, `positioning_hud.gd`, `scenes/positioning.tscn` | The positioning runtime: three studies (Choose your deck, The quiet landing, Prepare the receiver), the Lantern Fold, the courtyard chapter and the procedural turning frame. The generic parts became `runtime/architecture_runtime.gd` |
| `scripts/chapter_layout.gd`, `chapter_tests.gd` | Chapter 1 / The far light: turning courtyard blockout |
| `scripts/complete_puzzle*.gd` | The Lantern Fold |
| `scripts/monument_layout.gd`, `monument_tests.gd`, `scenes/monument.tscn` | Procedural Turning Frame (superseded by `monuments/turning_frame.tscn`) |
| `scripts/game.gd`, `hud.gd`, `scenes/main.tscn` | The original guided gallery, including portal (impossible-geometry) passages |
| `scripts/*_tests.gd` | Positioning, camera and overview regression suites |
| `scripts/surface_piece.gd`, `surface_walker.gd`, `curved_track.gd` | Copies of the traversal core at archive time (the live versions are in `core/`) |
| `tools/jev_*.mjs` | Directed state-based playtest scripts |
| `docs/` | Every prototype design doc, playtest note, camera experiment record, JSON report and screenshot, including the old spec/skill, `original-concept.md` (unchanged), `art-direction.md`, `game-vision.md` and `level-authoring-proposal.md` |

Useful as reference: the camera A/B decision (`docs/isometric-camera-experiment.md`), the reasoning-playtest protocol (`docs/playtest.md`), and the courtyard's interdependent-gallery ideas (`docs/chapter-one.md`).
