# First-person locomotion pass

Design and results, 1 October 2026. Status: **implemented, benchmarked; not yet hand-playtested.** Branch `feature/locomotion`. Since the [monumental scale](2026-10-01-monumental-scale.md) pass: walk speed 4.5 m/s, decel 0.08 s, default FOV 60°; the bench runs at ×4.

## Why

In The Ring v3, first person has its own job: interiors, top versus underside, sightlines. If moving feels uncomfortable or unreliable, that job fails. This pass makes the movement model specific to Elsewhere before more monuments are built on assumptions that might change. It is not a generic FPS controller: no sprint, crouch, lean, jump (§6.1) or heavy head bob.

**Acceptance:** the player thinks about the architecture, not about controlling the character. Failing because of the puzzle is fine. Failing because a seam caught you, forward stopped meaning forward, or the camera made you uncomfortable is a controller bug.

## What changed

| Area | Before | Now |
|---|---|---|
| Speed | constant 3.5 m/s, instant start and stop | 3.2 m/s; 0.18 s to full speed, 0.1 s to stop. Velocity is heading-relative, so momentum carries through ground changes |
| Direction | held W already followed the ground | unchanged: input is read in the ground frame and heading is carried by the minimal rotation |
| Gravity curves | view turned at speed / radius: 200°/s on the 1 m tower curl | speed is capped at turn rate × radius from the first frame on a curve. Normal 110°/s: the curl is walked at 1.9 m/s; the 2 m terrace curve is unaffected |
| View easing | whole camera transform eased at 16/s, including mouse look and position | only the ground orientation is eased (14/s), stored in the support's space; mouse look is 1:1 and never smoothed; eye position is rigid |
| Seams | a step cut short at a seam lost the rest of that frame (stutter) | time is spent on distance actually covered, so the step continues across the seam |
| Blocked steps | dead stop | slide along the ground's own axes, never further than asked |
| Comfort | sensitivity, reduced motion | + FOV (60–95, default 72), gravity transitions Gentle / Normal / Brisk (75 / 110 / 150°/s). Reduced motion now means gentle curves and no bob; it no longer snaps the first-person view |
| Head bob | none | 1 cm vertical at full speed; none on curves or with reduced motion; never roll |
| Interaction | F worked within reach, unannounced | a quiet "F  <label>" prompt appears only while something usable is within reach |
| Removed | third-person follow camera (unreachable), unused `curved_track.gd` | |

Feel lives in `core/locomotion.tres` (`LocomotionProfile`) and can be tuned in the inspector between runs. F3 shows the current speed, its cap and how fast the view is turning, so a comment like "that curve felt aggressive" can be matched to a number.

## Benchmark

`tests/locomotion_bench.gd` holds input frame by frame along The Ring's solved route (entry → tower → curl → upside down → underside arm → ring ride → terrace), plus an off-centre diagonal approach into the inner arm's narrow neck. It runs in the self-test, and every threshold asserts.

| Metric | Threshold | Baseline (old controller) | Now |
|---|---|---|---|
| Route segments that fail with one held key | 0 | 0 | 0 |
| Peak view rotation on gravity curves | ≤ 1.05 × comfort cap | 200°/s (1.8 × Normal) | 110°/s (1.00 ×) |
| Peak change of that rotation | ≤ 2400°/s² | 2816°/s² | 1323°/s² |
| Roll walking straight through a curve | ≤ 0.02 | 0 | 0 |
| Snags (held-input dips that recover) | 0 | 1 (balcony → terrace curve) | 0 |
| Mouse yaw shown in the same frame, measured about the ground normal | error ≤ 1 % | 23 % shown (77 % error) | 100 % |
| Time to 95 % speed | ≤ 0.25 s | 0 | 0.17 s |
| Distance after release | ≤ 0.2 m | 0 | 0.13 m |
| View drift relative to a support it rides, after a turn | ≤ 0.001 | large (eased back towards the old world orientation) | 0 |
| Slide overshoot | ≤ 0.0001 m | 0 | 0 |

## Architecture findings

Found by `tests/eye_clearance_probe.gd`, which checks every reachable pose in all 16 rotor configurations for an eye within 0.1 m of art:

- **Tower doors:** at 0.8 m, as wide as the path, the eye sat inside the door frame at the path edge. They are now 1.2 m, the cavity's width. The isometric start composition still reads them as slots and does not reveal the interior.
- **Entry and terrace jambs:** 0.1 m from the eye at the deck edge. Moved 10 cm out, with their glow strips and lintels.
- **Dead ends against a wall** (the inner arm's top end against the tower's solid east wall): the eye is 0.1 m from the wall. The near plane dropped from 0.07 to 0.04, so its corners stay inside 0.1 m even at FOV 95.
- The probe now reports 0 clipping places. The visible-deck rule (spec §7.2) is a test (`deck_cases`). The Ring already complied, because its narrowed necks build narrowed decks.

Not changed, to watch in playtest:

- **Mid-curl reference.** On the vertical part of the tower curl the view is mostly bare cavity wall for about a second. If players lose orientation there, add a warm reference on the cavity's east wall or carry the guide line up it, before considering a larger radius.
- **Curl radius 1 m** costs speed (1.9 m/s at Normal). A larger radius would need the tower's top and underside paths further apart than 2 m. Keep it unless the slowdown is noticed.
- **Speed drop at curve entry.** The cap applies from the first frame on the curve, so speed drops from 3.2 to 1.9 m/s at the seam (the view easing softens it). If it reads as a bump, add anticipatory slowing before the seam.

## Playtest script

Start from a fresh save at Normal settings. Run The Ring's route **three times**. Each time, note any moment of:

1. motion discomfort (where, and what the F3 view-rate read);
2. lost control, or not knowing which way is forward;
3. catching on an edge or a seam;
4. fighting the camera;
5. not being able to tell where the walkable edge is.

Then try Gentle and Brisk once each, and FOV 60 and 90 once each. Note which you would keep.

## Out of scope

- A blend between first person and isometric when switching (the cut stays; revisit if players lose orientation on Tab).
- A fade or cut option for major gravity changes; decide after a human tries reduced motion.
- A seam funnel (lateral help into narrow sockets): the stall metric found no snags, so none was built. If one is ever needed it must correct sideways only, a few centimetres per frame, never pull forward, and never into another path.
- Sprint, crouch, lean, jump, remapping UI.
