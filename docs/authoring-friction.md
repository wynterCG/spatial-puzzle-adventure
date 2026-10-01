# Authoring friction log

1 October 2026. Separate repeated setup work from puzzle-design decisions.

| Observed repetition | Response | Still manual |
|---|---|---|
| Building flat paths, contact endpoints and carrier dictionaries in every GDScript layout | Scene components, automatic end sockets and shared runtime adapter | Path placement, lengths, available grounds and intended dependency |
| Every prototype assumes four quarter-turn states | Explicit ordered angle states and optional nonwrapping hinges | Which configurations should exist and what each accomplishes |
| Looking at a runtime-only layout to understand authored ground | Editor path/normal drawing and isolated configuration preview | Choosing a useful composition and sightline |
| Repeating a walk to an underside during tests | Play From Here with path/marker and preview state | Selecting which situation needs investigation |
| Checking nearby paths that still fail to join | Shared socket compatibility and diagnostics, including physical aperture width | Deciding whether an open connection is intentional |
| Saving a new layout over an incompatible old contact | Per-level IDs/revisions and separate authored saves | Migration policy after substantial redesign |
| Bell Cradle's broad goal intersected its rotating arm | Test found the sweep collision; authored walking/collision regions narrowed the landing | The correct architectural clearance; no bypass flag was added |

The Turning Frame, Bell Cradle and Folded Observatory are mechanically tested blockouts. Further human playtests and new spatial ideas should guide the next tools. Socket snapping and a rigid tile library are not justified merely because it is possible to build them.
