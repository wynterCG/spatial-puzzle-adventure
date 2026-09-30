# First chapter plan

**Status: proposed blockout, not implemented.** This plan tests the [game vision](game-vision.md) with a short continuous route. Names below describe design functions; they are not final lore or level names. Preserve the existing prototype layouts as selectable references.

## The journey

Arrival overlook → surface crossing → split-path assembly → fixed transfer landing → quiet underside passage → the destination seen at arrival.

Keep the active assembly bounded and readable, with surrounding open space suggesting a larger place. Show the destination at the entrance and again after the main discovery. The final approach reaches its underside from an unexpected orientation. This is physical surface-relative traversal, not a portal reveal.

The confirmed camera pairing is first-person exploration and isometric B. Use it throughout the chapter; playtesting evaluates comprehension, transitions and comfort with that pairing. Manual orbit remains an inspection tool to evaluate, and optional third person remains available in the existing prototype.

The chapter introduces a rule, asks for a positional decision, then changes the situation so the player must apply the rule rather than repeat the previous actions. The first blockout should test that claim before adding another mechanism.

## Entrance and observation

**Intended discovery:** “My ground can change along an authored route, and the external view helps me understand where that route goes.”

Begin on a safe overlook with the destination visible. A short marked curve leads onto a different ground plane. A small moving bridge then introduces the difference between inspecting architecture, changing it and walking across it. Give the bridge one clear useful connection and make its endpoints visible before a turn.

Use brief control prompts when needed, not a step-by-step solution chain. Let the player switch views before reaching the curve. Returning to the overlook and crossing again should be possible without restart.

**Observe:** can the player identify intentional walking surfaces, describe what a bridge rotation will carry, and use the two views without losing their route? If the curve or camera alone prevents progress, address that before judging the next puzzle.

## Development and positional choice

**Intended discovery:** “The structure can reach the destination while I remain on the wrong path; I need to change my position before it moves.”

Use a carrier with visibly separate short and long paths. The immediate boarding route reaches the short path. A fixed curved approach reaches the longer underside path. A useful carrier rotation connects the long path to the next fixed landing, while the short path still ends early.

Arrange the view so the length difference and next landing are inspectable together. The wrong-path attempt must reveal a visible gap rather than an unexplained action denial. The player can return the carrier, walk back and try the other approach; undo remains available.

Reuse the tested path-choice rule from Study 1 and Lantern Fold. Change its placement to serve the chapter's entrance and onward route; do not import Lantern Fold's receiver-clearance puzzle merely to increase the action count.

**Observe:** before turning, ask for the player's prediction. After a wrong-path attempt, can they explain why the structure's configuration was insufficient? Do they deliberately seek the other path rather than cycle rotations until something works?

## Conclusion and independent application

**Intended discovery:** “Sometimes preparing my position means leaving the moving structure, so it can bring a different path to where I am waiting.”

The development exit leads physically onto the first path of a different carrier. Its first useful turn reaches a fixed transfer landing. A second, separate path on this carrier has a different ground direction and can meet the landing's curved return only after the carrier turns again. The first path cannot reach the final passage.

The player must step onto fixed ground, turn the now-empty carrier, follow the fixed curve to its other path, then cross toward the destination. Staying aboard the first path carries the player away from the preparation route. Returning the carrier restores access, so the mistake is reversible.

Use Study 2's tested relationship as a starting point, with a different silhouette and connection arrangement from the development puzzle. Do not give another full instruction explaining where to stand. Optional hints remain available and are recorded during testing.

**Observe:** does the player recognize the need to change paths in a new configuration? Do they distinguish staying aboard in the previous puzzle from stepping off here? If this feels like the same discovery repeated with extra walking, revise the layout before adding more mechanisms.

## Quiet arrival and spatial reward

After the final carrier, provide a short fixed passage without another mechanism. Keep its walking surface consistent with the final path's gravity so the unexpected orientation is earned by the route already taken. Reveal the recognizable destination as the player approaches its underside.

Allow a pause to look back at the transformed route and conclude the chapter. Do not add an inventory check, unexplained door lock or forced camera change to make the ending happen. Judge whether the arrival feels connected to the original sightline; a completion popup alone is not the intended reward.

## Blockout construction order

1. **Sketch contacts and sightlines.** Map each starting surface, carrier pivot, docking endpoint, safe waiting area and return path. Confirm the final gravity plane before placing the destination. Use ordinary geometry throughout.
2. **Build the whole route crudely.** Make all three beats and their connecting passages traversable before polishing an individual puzzle. Reuse the walker, authored curve, contact matching, swept-turn checks and B camera baseline.
3. **Integrate the overview.** Keep a stable focus for each active assembly. Proposed focus changes occur on fixed connecting ground, preserve the transported orientation and manual inspection layer, and avoid a sudden switch while a carrier turns. Treat focus-transition behavior as a chapter-specific experiment, not a solved camera feature.
4. **Add recovery and continuity.** Keep prior assemblies coherent when backtracking. Preserve configuration and position across settled saves; undo must restore the correct assembly and passenger. Add the chapter as a separate selectable entry with its own progress storage, so study saves remain intact.
5. **Add a small visual sample.** Use one representative junction to compare walkability, pivot readability and contact contrast in both views, including inverted ground. Carry only useful changes into the simple geometry.
6. **Verify and playtest.** Exercise intended routes, tempting wrong orders, backtracking, undo, save/reload and camera transitions. Then observe players who have not been taught the isolated studies.

These are planned tasks. Cross-assembly focus, chapter persistence and connected routing are not implemented by the current prototype. Do not rebuild the working project just to create a new chapter.

## Playtest and decision record

For the initial qualitative pass, propose three to five players unfamiliar with the prototypes. This is a practical discovery round, not statistical validation or a promise of a completion rate. Introduce controls only, keep hints optional, and avoid revealing the intended solution during an attempt.

| Signal | Record | If it fails |
|---|---|---|
| Rule comprehension | What the player thinks can be walked on, and what a rotation carries | Clarify geometry or teaching before adding difficulty |
| Route anticipation | Their predicted next connection before a turn and explanation afterward | Improve endpoint, pivot or gap readability |
| Independent discovery | Whether they deliberately change paths in development and step off in the conclusion | Revise the dependency or the transfer between lessons |
| Camera versus puzzle difficulty | Exact moment of lost orientation, occlusion or discomfort; view and action involved | Fix or compare the camera separately from puzzle difficulty |
| Spatial reward | Recognition of the original destination and reaction to the changed approach | Adjust sightlines and the final passage |
| Desire to continue | Whether they want another section and what they expect to discover | Reconsider pacing or variety rather than simply adding puzzles |

Record attempts, predictions, hints, recoveries and player explanations before revealing solutions. Separate an unexplained successful sequence from a demonstrated understanding of why the order matters. Use Jev or scripted checks for bounded regressions; they do not substitute for human comprehension or comfort evidence.

## Readiness for a vertical slice

Advance after observed players can distinguish the intended discoveries, apply the positional rule in the final configuration without a repeated full explanation, and reach a spatially meaningful conclusion. Recurring camera or traversal confusion must be resolved enough to assess the puzzles fairly. If evidence is mixed, record it and revise the chapter; do not treat a technical PASS as this decision.

Then choose one proven section to finish, including its entry and exit transitions. Evaluate both the experience and the repeatability of producing its assets, audio, interactions and QA. Keep full campaign planning provisional until this smaller journey and its production process provide evidence.
