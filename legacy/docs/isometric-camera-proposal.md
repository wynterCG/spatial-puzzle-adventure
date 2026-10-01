# Proposed Isometric Camera Adjustments

**Keep the ground-relative camera system, but test separating changes in gravity from the supporting structure’s full rotation.** This is a targeted experiment, not a recommendation to replace the camera with a world-fixed system.

## 1. Preserve the Existing Behaviour

Keep the fixed centre for each puzzle, the camera’s independence from character facing and first-person look direction, and the continuous viewing direction when crossing between connected pieces.

**Tab should continue to reveal the existing overview without resetting its angle.** Looking around in character view should not overwrite the architectural view the player has established.

Also preserve the continuous change in camera orientation when walking around a curved track. The camera can continue treating the character’s current supporting surface as the floor.

## 2. Follow Changes in Gravity, Not Every Rotation of the Structure

The main change to test concerns rotations that **do not change the direction of the ground beneath the character**.

For example, imagine the occupied carrier rotating like a turntable. It turns 90 degrees, but its deck remains horizontal and gravity does not change.

In that situation, test the following:

> The carrier rotates and carries the character with it, but the camera does not automatically orbit with the carrier.

The camera does not need to rotate to remain above the same ground direction. Holding its viewing orientation would let the player observe the carrier turning toward a new connection.

By contrast, when the carrier tilts and changes the character’s local ground direction, the camera would continue following that change.

**The proposed rule is: follow the changing ground normal, rather than inheriting the supporting structure’s complete orientation.**

| Situation | Behaviour to test |
|---|---|
| The occupied structure tilts the ground | The camera follows the changing ground direction. |
| The occupied structure rotates without changing the ground direction | The structure and character rotate; the camera does not automatically orbit. |
| Another structure rotates | The camera’s reference remains unchanged. |
| The character walks around a curved track | The camera follows the changing ground continuously, as it does now. |
| The character crosses between connected pieces | Preserve viewing continuity; do not adopt the new piece’s local forward direction. |
| The character turns or looks around | Do not rotate the isometric camera. |

The character must still inherit the occupied structure’s **full transformation**. This proposal changes camera behaviour, not player attachment.

It also does not eliminate all automatic camera movement. Transformations that tilt the ground would still reorient the camera.

## 3. Add Manual Orbit as a Separate Layer

Allow the player to orbit the overview for inspection, while keeping that input separate from automatic ground-relative orientation.

The distinction should be:

> **The ground establishes the orientation reference. The player chooses the viewing direction around the puzzle.**

A player might orbit to inspect a connection behind the carrier. That chosen view should persist when switching between character and architectural views. A carrier rotation that leaves gravity unchanged should not automatically replace that choice.

When the ground direction changes, carry the chosen view continuously into the new ground-relative frame. Do not rebuild the camera orientation from the occupied piece’s forward and right axes, because that could reintroduce unwanted heading changes when crossing between pieces.

Keep orbit centred on the puzzle, with controlled elevation and limited zoom rather than unrestricted free-flight movement. A separate **Reset View** action can restore a recommended framing; Tab should remain exclusively a perspective switch.

Use clearly distinct controls for orbiting the camera and rotating structures.

## 4. Compare Before Committing

The current behaviour is not necessarily wrong. It may communicate the intended feeling of the world reorganizing around the character’s ground. Without observing the animation and player behaviour, the proposed adjustment remains a hypothesis.

Compare two versions using the same carrier:

**Version A — Current behaviour:** the camera inherits the occupied structure’s full rotation.

**Version B — Ground-direction following:** the camera follows changes in the ground direction but does not inherit rotation around an unchanged ground normal.

Test this comparison **before adding manual orbit**, so the effect of the automatic camera behaviour can be evaluated independently.

Watch whether players can identify what moved, understand where the character ended up, and recognize which connection opened. Include both a turntable-style rotation and a rotation that tilts the ground.

**The goal is not simply to minimize camera movement. It is to make structural transformations readable while retaining a coherent relationship to the character’s ground.**