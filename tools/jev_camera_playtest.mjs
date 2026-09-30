// Bounded Jev camera/control regression against the live positioning scene.
// Uses the real camera-relative input path. State perception, not visual QA.
import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const cli = process.env.GODOT_MCP_CLI;
const key = process.env.TYPESAFE_API_KEY;
if (!cli || !key) throw new Error('Set GODOT_MCP_CLI and TYPESAFE_API_KEY.');
function runtime(code) {
  const run = spawnSync(process.execPath, [cli, 'runtime', 'exec', '--code', code], {
    encoding: 'utf8', timeout: 30000, windowsHide: true,
  });
  if (run.status !== 0) throw new Error('MCP runtime failed.');
  const result = JSON.parse(run.stdout.slice(run.stdout.indexOf('{')));
  if (!result.output?.length) throw new Error('Missing runtime observation.');
  return JSON.parse(result.output.at(-1));
}
const observe = `
g.update_camera()
g.walker.avatar.visible = true
g.hud.refresh()
var s = g.walker.support
_mcp_print(JSON.stringify({
    'support': str(s.name), 'foot': [g.walker.foot.x, g.walker.foot.y, g.walker.foot.z],
    'curve_distance': s.distance_at(g.walker.foot) if s.has_method('distance_at') else -1,
    'view': 'overview' if g.architectural else 'third_person',
    'camera_upright': g.walker.camera.global_basis.y.dot(Vector3.UP),
    'avatar_up': g.walker.avatar.global_basis.y.dot(Vector3.UP),
    'camera_finite': g.walker.camera.global_transform.is_finite(),
    'camera_distance': g.walker.camera.global_position.distance_to(g.walker.avatar.to_global(Vector3(0,.85,0))),
    'max_frame_jump': max_jump, 'max_frame_degrees': max_angle
}))
`;
const criteria = {
  forward: 'Hold W for half a second using the real camera-relative controls.',
  backward: 'Hold S for half a second using the real camera-relative controls.',
  stop: 'Release the walking keys for ten frames, then choose a new input.',
  look_up: 'Move the mouse vertically to adjust the pitch, without changing walking direction.',
  look_down: 'Move the mouse vertically in the other direction.',
  orbit_check: 'Make a small left mouse yaw, walk briefly, then yaw back and resume. Tests steering on a curved wall.',
  switch_view: 'Toggle between traversal and isometric. Walking is disabled in isometric.',
};
const report = { model: '', mode: 'Directed route regression: Jev chooses control-check order from structured observations; no screenshot perception or blind puzzle solving', steps: [], completed: false };
let initialized = false;
try {
  let state = runtime(`
var g = get_tree().current_scene
if g.get_script().resource_path != 'res://scripts/positioning_game.gd' or g.busy:
    _mcp_print(JSON.stringify({'error': 'Open a settled positioning study first.'}))
    return
g.set_meta('jev_camera_resume', {'snapshot':g.snapshot(), 'initial':g.initial.duplicate(true), 'history':g.history.duplicate(true), 'completed':g.completed.duplicate(), 'architectural':g.architectural, 'paused':g.paused, 'won':g.won, 'process':g.is_processing(), 'input':g.is_processing_unhandled_input(), 'third_person':g.walker.third_person, 'world':g.walker.keep_world_horizon, 'reduced':g.walker.reduced_motion})
g.set_process(false)
g.set_process_unhandled_input(false)
g.load_trial(0)
g.walker.third_person = true
g.walker.keep_world_horizon = true
g.walker.reduced_motion = false
g.walker.camera_initialized = false
g.walker.world_orbit_initialized = false
g.walker.orbit_changed = false
g.walker.place(g.start, Vector3(0,.2,0), Vector3.UP, Vector3.FORWARD)
g.architectural = false
g.walker.camera.current = true
var max_jump = 0.0
var max_angle = 0.0
${observe}`);
  if (state.error) throw new Error(state.error);
  initialized = true;
  let reachedLower = false;
  let stoppedOnCurve = false;
  let changedPitchOnCurve = false;
  let changedViewOnCurve = false;
  let orbitedOnCurve = false;
  for (let step = 0; step < 36; step++) {
    // This is a directed regression, not a blind puzzle playtest: constrain the
    // route leg while Jev chooses when to exercise each camera/control action.
    const available = Object.fromEntries(Object.entries(criteria).filter(([name]) => {
      if (state.view === 'overview') return name === 'switch_view';
      if (name === 'forward') return !reachedLower;
      if (name === 'backward') return reachedLower;
      if (state.support !== 'Rounded_path') return false;
      if (name === 'stop') return !stoppedOnCurve;
      if (name.startsWith('look_')) return !changedPitchOnCurve;
      if (name === 'orbit_check') return !orbitedOnCurve;
      return name === 'switch_view' && !changedViewOnCurve;
    }));
    const response = await fetch('https://api.typesafe.ai/v1/systemone', {
      method: 'POST', signal: AbortSignal.timeout(20000),
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'jev-latest', state: {
        objective: 'Directed camera regression: follow the known route to Lower_landing with W, then return to Arrival with S. On the curve, stop and restart, change pitch, run orbit_check, and switch to overview and back. Exercise available checks early on the curve before completing the route. This tests controls, not puzzle reasoning.',
        rules: 'The camera begins aimed along the curve from Arrival. W should continue around the curve despite stopping, pitch changes, or view switches; S reverses along it. Curve distance increases toward Lower_landing. No turning or puzzle solving is needed. Use switch_view twice to resume walking. Each walk lasts 30 frames.',
        current: state, reached_lower: reachedLower, stopped_on_curve: stoppedOnCurve,
        changed_pitch_on_curve: changedPitchOnCurve, changed_view_on_curve: changedViewOnCurve,
        orbited_on_curve: orbitedOnCurve,
        recent: report.steps.slice(-6),
      }, questions: { action: { type: 'choice', instructions: 'Choose the next test action to cover the required cases and finish the return trip.', criteria: available } } }),
    });
    if (!response.ok) throw new Error(`TypeSafe HTTP ${response.status}; response body not logged.`);
    const decision = await response.json();
    report.model = decision.model;
    const action = decision.answers?.action?.choice;
    if (!Object.hasOwn(available, action)) throw new Error('Jev returned an unavailable action.');
    const onCurve = state.support === 'Rounded_path';
    stoppedOnCurve ||= onCurve && action === 'stop';
    changedPitchOnCurve ||= onCurve && action.startsWith('look_');
    changedViewOnCurve ||= onCurve && action === 'switch_view';
    orbitedOnCurve ||= onCurve && action === 'orbit_check';
    const y = action === 'forward' ? -1 : action === 'backward' ? 1 : action === 'orbit_check' ? (reachedLower ? 1 : -1) : 0;
    const frames = action === 'orbit_check' || y === 0 ? 10 : 30;
    const code = `
var g = get_tree().current_scene
var max_jump = 0.0
var max_angle = 0.0
${action === 'switch_view' ? 'g.toggle_view()' : ''}
${action.startsWith('look_') ? `g.walker.look(Vector2(0, ${action === 'look_up' ? -20 : 20}))` : ''}
${action === 'orbit_check' ? 'g.walker.look(Vector2(10,0))' : ''}
for i in range(${frames}):
    var before = g.walker.camera.global_transform
    if not g.architectural:
        var movement = Vector2(0, ${y})
        g.walker.align_movement_to_camera(movement)
        g.walker.walk(movement, 1.0 / 60)
    g.walker.sync_pose(1.0 / 60)
    max_jump = max(max_jump, before.origin.distance_to(g.walker.camera.global_position))
    max_angle = max(max_angle, rad_to_deg(before.basis.get_rotation_quaternion().angle_to(g.walker.camera.global_basis.get_rotation_quaternion())))
${action === 'orbit_check' ? 'g.walker.look(Vector2(-10,0))' : ''}
${observe}`;
    state = runtime(code);
    reachedLower ||= state.support === 'Lower_landing';
    report.steps.push({ action, ...state });
    console.log(`${step + 1}: ${action} -> ${state.support} ${state.view}; jump ${state.max_frame_jump.toFixed(3)}, turn ${state.max_frame_degrees.toFixed(2)}`);
    if (reachedLower && state.support === 'Arrival' && stoppedOnCurve && changedPitchOnCurve && changedViewOnCurve && orbitedOnCurve) {
      report.completed = true;
      break;
    }
  }
  report.coverage = { reachedLower, stoppedOnCurve, changedPitchOnCurve, changedViewOnCurve, orbitedOnCurve };
  report.cameraChecksPassed = report.steps.every(s => s.camera_finite && s.camera_upright > .5 && s.camera_distance > .45 && s.max_frame_jump < .65 && s.max_frame_degrees < 8);
} finally {
  if (initialized) runtime(`
var g = get_tree().current_scene
var saved = g.get_meta('jev_camera_resume')
g.load_trial(saved.snapshot.trial)
g.walker.third_person = saved.third_person
g.walker.keep_world_horizon = saved.world
g.walker.reduced_motion = saved.reduced
g.restore(saved.snapshot)
g.initial = saved.initial
g.history.assign(saved.history)
g.completed = saved.completed
g.architectural = saved.architectural
g.paused = saved.paused
g.won = saved.won
g.overview.current = saved.architectural
g.walker.camera.current = not saved.architectural
Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if saved.paused or saved.architectural or saved.won else Input.MOUSE_MODE_CAPTURED
g.hud.sync_preferences()
g.hud.refresh()
g.set_process(saved.process)
g.set_process_unhandled_input(saved.input)
g.remove_meta('jev_camera_resume')
_mcp_print(JSON.stringify({'restored':true}))
`);
  writeFileSync('docs/jev-camera-report.json', JSON.stringify(report, null, 2) + '\n');
}
console.log(report.completed && report.cameraChecksPassed ? 'JEV CAMERA PASS' : 'JEV CAMERA INCOMPLETE OR FAILED: review trace');
process.exitCode = report.completed && report.cameraChecksPassed ? 0 : 1;
