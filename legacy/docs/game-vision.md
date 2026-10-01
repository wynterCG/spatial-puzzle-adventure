# Elsewhere game vision

Working direction, 30 September 2026. This document guides the next chapter experiment; [spec.md](spec.md) describes what the prototype currently implements. The revised [turning-courtyard chapter](chapter-one.md) is now playable. [Art and level-design direction](art-direction.md) requires recognizable architecture and interdependent pieces; the previous sequential chapter layout is superseded. Its learning progression and broader camera comfort still need human playtesting.

## The experience

The immediate study is now [The turning frame](monument-study.md), alongside the preserved courtyard. It tests whether one recognizable object can communicate the existing positional dependency more clearly. Architecture supplies the actual routes and transformation; a larger enclosure and extra mechanisms are deferred. This comparison precedes any commitment to final chapter geometry or a vertical slice.

A contemplative journey through fantastical structures, where understanding where to position yourself allows you to transform the architecture and open the next path.

The desired progression of experience is curiosity, understanding the rules, anticipating a route, transforming the architecture, and enjoying the passage through what you prepared. The central question remains: **Where do I need to be before I transform the space?**

First-person exploration makes distances, surfaces and crossings tangible. Isometric observation with camera B makes the relationships between structures legible. Neither view should solve the puzzle alone: architecture changes what can connect, while movement determines which connection the player can use.

## Decisions and evidence

| Topic | Status | Consequence for the next milestone |
|---|---|---|
| Position, configuration and action order | Confirmed design direction; individual mechanisms work in the prototype | Build different discoveries from those rules before adding systems |
| Existing studies, Lantern Fold and gallery | Preserved prototype references | Reuse code and lessons; no layout is automatically part of the final game |
| Development sequence | Adopted direction | Vision, connected chapter in simple geometry, playtesting, then a representative vertical slice |
| Character perspective | Confirmed by the user: first person with isometric B; already the current default | Build the chapter around first-person exploration. Retain optional third person in the prototype without making it a parallel development priority |
| Isometric transport B | Confirmed alongside first person; user preference: “it reads way better”; regression-tested behavior | Carry this direction into the chapter. Comprehension and comfort across players remain hypotheses, not reasons to treat the preference as undecided |
| Manual overview orbit | Implemented inspection option | Test whether it helps reading connections without making camera management the main challenge |
| Impossible connections | Optional, retained in the gallery | The next chapter must work using physical connections alone |
| Continuous journey through bounded assemblies | Implemented as a blockout; progression validation pending | Test one small route with visible destinations; defer hub and open-world commitments |
| Identity, story and final visual style | Open | Use a recognizable destination and minimal motivation; test visual readability in a small sample |

## Rules for choosing content

Every puzzle needs an intended discovery expressible as a causal statement. “I must step off before turning, because remaining aboard removes access to the route I need” is a useful target. “A harder puzzle with two platforms” is not sufficient.

Preserve authored paths, curved gravity transitions and clear ordinary edges. Moving structures carry the player's current contact; rotations never silently put them on a more useful path. Physical reach, matching surfaces and clearance should explain the dependencies. Camera angle does not enable a connection.

Give mistakes an observable consequence and a way back. Undo is available, but ordinary withdrawal or returning a structure should also recover useful wrong-order attempts. Avoid time pressure and irreversible failure in the first chapter so the test measures spatial reasoning.

Accept a new mechanic only if a specific intended discovery cannot be expressed clearly with the existing rules. More levers, transformations or travel distance do not by themselves create a new discovery.

## Narrative and visual direction

For the chapter, the player's immediate motivation is to reach a destination visible near the beginning. Whether the larger game is about discovery, reactivation or crossing this place remains open. Do not add inventory, dialogue characters, quests or collection requirements to support an unchosen story.

Use the existing restrained palette as a starting sample, not a final art commitment. Walkable surfaces, static supports, moving assemblies, pivots and joined contacts must be distinguishable in both views and under inverted gravity. Test one small set of materials, lighting and silhouettes alongside the chapter blockout. Do not finish every environment asset before the journey has been tested.

## Development milestones

1. **Vision and chapter plan:** define the experience, each intended discovery, the connected route and what evidence would support it. This document and [first-chapter-plan.md](first-chapter-plan.md) are that planning baseline.
2. **Playable chapter with simple geometry:** one entrance, a development section, an independent application and a quiet arrival. Keep layouts cheap to revise. Reuse working traversal and transformation code.
3. **Playtesting and revision:** distinguish rule comprehension, route anticipation, camera difficulty and enjoyment. Revise repeated or unreadable discoveries before expanding content.
4. **Representative vertical slice:** bring a proven section to the intended quality and measure the process for producing more of it: modeling, materials, animation, sound, integration, saves, QA and iteration. Choose a section containing exploration, transformation and a crossing, not just an attractive vista.

The next milestone is a small journey in which the player learns, makes an independent discovery and wants to see what comes next. A chapter that merely looks finished does not meet that milestone. Total game length, chapter count, platform targets, release scope and production schedule remain undecided.
