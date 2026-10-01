// Bounded, state-based Jev playtest through the user's local Godot MCP Pro CLI.
// No SDK dependency. API credentials are read only from the environment.
import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const cli = process.env.GODOT_MCP_CLI;
const key = process.env.TYPESAFE_API_KEY;
if (!cli || !key) throw new Error('Set GODOT_MCP_CLI and TYPESAFE_API_KEY before running.');
function runtime(code) {
  const result = spawnSync(process.execPath, [cli, 'runtime', 'exec', '--code', code], {
    encoding: 'utf8', timeout: 30000, windowsHide: true,
  });
  if (result.status !== 0) throw new Error('Godot MCP runtime command failed.');
  const start = result.stdout.indexOf('{');
  const response = JSON.parse(result.stdout.slice(start));
  if (!response.output) throw new Error('Godot did not return a runtime observation.');
  return JSON.parse(response.output.at(-1));
}
const observe = `
game.walker.sync_pose(1)
game.update_overview_camera()
game.walker.avatar.visible = game.architectural or game.walker.third_person
game.walker.update_overview_visibility(game.overview, game.architectural)
game.update_passage_views()
game.hud.refresh()
var observation = {
    'piece': str(game.walker.support.name),
    'foot_local_xz': [game.walker.foot.x, game.walker.foot.z],
    'foot_local_y': game.walker.foot.y,
    'track_open': game.track_open, 'carrier_released': game.carrier_released,
    'interaction': game.available_interaction(),
    'track_distance': game.rounded_track.distance_at(game.walker.foot) if game.walker.support == game.rounded_track else -1,
    'carrier_state': game.carrier.state, 'gallery_state': game.arch_state,
    'view': 'overview' if game.architectural else 'traversal',
    'guidance': game.guidance(), 'feedback': game.message,
    'complete': game.walker.support == game.destination and game.walker.foot.z < -14,
    'connected_neighbours': [], 'walkable_regions_xz': [],
    'overview_occlusion_silhouette': game.walker.overview_silhouette.visible
}
for neighbour in game.walker.support.neighbours:
    observation.connected_neighbours.append(str(neighbour.name))
for region in game.walker.support.walk_regions:
    observation.walkable_regions_xz.append([region.position.x, region.end.x, region.position.y, region.end.y])
_mcp_print(JSON.stringify(observation))
`;
const criteria = {
  east: 'Walk +local X for 2 units in traversal view.',
  west: 'Walk -local X for 2 units in traversal view.',
  north: 'Walk forward along the surface for 2 units: -Z on a flat support, toward the underside on the rounded track.',
  south: 'Walk back along the surface for 2 units: +Z on a flat support, toward the entrance on the rounded track.',
  interact: 'Operate the nearby control in traversal view when interaction is available.',
  east_small: 'Walk +local X for 0.5 units in traversal view.',
  west_small: 'Walk -local X for 0.5 units in traversal view.',
  switch_view: 'Toggle overview/traversal. Walking requires traversal; turning requires overview.',
  carrier_right: 'Select carrier and turn it +1 quarter in overview.',
  carrier_left: 'Select carrier and turn it -1 quarter in overview.',
  gallery_right: 'Select gallery and turn it +1 quarter in overview.',
  gallery_left: 'Select gallery and turn it -1 quarter in overview.',
};
const report = { model: '', mode: 'structured-state agent; no screenshot perception; controls filtered by active view', steps: [], completed: false };
let initialized = false;
try {
  let state = runtime(`
var game = get_tree().current_scene
if game.get_script().resource_path != 'res://scripts/game.gd':
    _mcp_print(JSON.stringify({'error': 'This runner supports the original gallery only. Open it from Studies & settings before testing.'}))
    return
if game.busy:
    _mcp_print(JSON.stringify({'error': 'Wait until the game settles before testing.'}))
    return
game.set_meta('jev_resume', {'scene': game.snapshot(), 'checkpoint': game.checkpoint, 'history': game.history.duplicate(true), 'selected': game.selected, 'architectural': game.architectural, 'paused': game.paused, 'won': game.won, 'process': game.is_processing(), 'input': game.is_processing_unhandled_input(), 'third_person': game.walker.third_person, 'save_exists': FileAccess.file_exists('user://journey.save'), 'save_bytes': FileAccess.get_file_as_bytes('user://journey.save') if FileAccess.file_exists('user://journey.save') else PackedByteArray()})
game.set_process(false)
game.set_process_unhandled_input(false)
game.walker.set_third_person(true)
game.new_journey()
${observe}`);
  if (state.error) throw new Error(state.error);
  initialized = true;
  let blockedActions = new Set();
  for (let step = 0; step < 60 && !state.complete; step++) {
    const available = Object.fromEntries(Object.entries(criteria).filter(([action]) =>
      !blockedActions.has(action) && (action !== 'interact' || state.interaction) && (action === 'switch_view' ||
      (state.view === 'overview' ? action.startsWith('carrier_') || action.startsWith('gallery_') : !action.startsWith('carrier_') && !action.startsWith('gallery_')))));
    const response = await fetch('https://api.typesafe.ai/v1/systemone', {
      method: 'POST', signal: AbortSignal.timeout(20000),
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'jev-latest', state: {
        objective: 'Play this spatial puzzle to reach the light on Destination (local z < -14). Choose one next control. Avoid repeating blocked actions.',
        rules: 'Only ivory authored paths allow walking. Ordinary edges stop you. The carrier carries its passenger when turned. State 0 links Arrival/Causeway; state 1 links Courtyard, whose ground has a different world orientation. Gallery state 0 joins the passage; turning requires a safe position on the landing outside its sweep. First extend the folded walkway using the nearby control on Arrival. Follow the branch at local X=-1.8 toward Z=-3 and around the rounded track; its far control releases the carrier brake. Return along the same curve before boarding. North/south follow the curved surface toward/away from the underside. Elsewhere coordinates are support-local; +X is east and -Z is north. Arrival feeds Causeway then Carrier along +X. Courtyard has an east/west landing and a northward gallery path around X=0. Destination continues north to the light. Surface transfers use actual touching paths; gallery crossing is automatic. A control may be blocked and report why.',
        current: state, recent: report.steps.slice(-8).map(s => ({ action: s.action, after: s.after })),
      }, questions: { action: { type: 'choice', instructions: 'Which next control best advances toward the light, respecting the current view and geometry?', criteria: available } } }),
    });
    if (!response.ok) throw new Error(`TypeSafe returned HTTP ${response.status}; no response body logged.`);
    const decision = await response.json();
    report.model = decision.model;
    const action = decision.answers?.action?.choice;
    if (!Object.hasOwn(available, action)) throw new Error('Jev returned an unavailable action.');
    const movement = { east: [1, 0, 2], west: [-1, 0, 2], north: [0, -1, 2], south: [0, 1, 2], east_small: [1, 0, 0.5], west_small: [-1, 0, 0.5] }[action];
    let code = 'var game = get_tree().current_scene\n';
    if (movement) {
      code += `if not game.architectural and not game.busy:
    game.walker.forward = game.walker.support.surface_frame(game.walker.foot) * Vector3(${movement[0]}, 0, ${movement[1]})
    for frame in range(${Math.round(movement[2] * 60 / 3.5)}):
        game.walker.walk(Vector2(0, -1), 1.0 / 60.0)
        game.check_passage()
`;
    } else if (action === 'interact') code += 'game.interact()\nif game.busy:\n    game.rotation_tween.custom_step(1.5)\n';
    else if (action === 'switch_view') code += 'game.toggle_view()\n';
    else code += `game.select_piece(${action.startsWith('carrier') ? 0 : 1})
game.rotate_selected(${action.endsWith('right') ? 1 : -1})
if game.busy:
    game.rotation_tween.custom_step(1.0)
`;
    const after = runtime(code + observe);
    const pose = s => JSON.stringify([s.piece, s.foot_local_xz, s.foot_local_y, s.carrier_state, s.gallery_state, s.view, s.track_open, s.carrier_released]);
    if (pose(after) === pose(state)) blockedActions.add(action);
    else blockedActions.clear();
    report.steps.push({ action, confidence: decision.answers.action.confidence, before: state, after });
    state = after;
    console.log(`${step + 1}: ${action} -> ${state.piece} (${state.foot_local_xz.map(n => n.toFixed(2))}) ${state.view}`);
  }
  report.completed = state.complete;
} finally {
  if (initialized) runtime(`
var game = get_tree().current_scene
var saved = game.get_meta('jev_resume')
game.architectural = saved.architectural
game.walker.set_third_person(saved.third_person)
game.restore(saved.scene)
game.checkpoint = saved.checkpoint
game.history.assign(saved.history)
game.select_piece(saved.selected)
game.won = saved.won
game.hud.completion.visible = saved.won
game.set_pause(saved.paused)
if saved.save_exists:
    var file = FileAccess.open('user://journey.save', FileAccess.WRITE)
    file.store_buffer(saved.save_bytes)
    file.close()
elif FileAccess.file_exists('user://journey.save'):
    DirAccess.remove_absolute('user://journey.save')
game.set_process(saved.process)
game.set_process_unhandled_input(saved.input)
game.remove_meta('jev_resume')
${observe}`);
  // Keep a readable action trace without duplicating the whole observation.
  const trace = { ...report, steps: report.steps.map(({ action, confidence, after }) => ({
    action, confidence, piece: after.piece, foot_local_xz: after.foot_local_xz,
    view: after.view, carrier: after.carrier_state, gallery: after.gallery_state,
    track_distance: after.track_distance, track_open: after.track_open, carrier_released: after.carrier_released,
    complete: after.complete,
  })) };
  writeFileSync('docs/jev-playtest-report.json', JSON.stringify(trace, null, 2) + '\n');
}
console.log(report.completed ? 'JEV PLAYTEST: destination reached.' : 'JEV PLAYTEST: step budget exhausted; review the trace.');
process.exitCode = report.completed ? 0 : 1;
