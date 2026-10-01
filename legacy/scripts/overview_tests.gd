extends RefCounted

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var helper = preload("res://scripts/positioning_tests.gd")
	g.walker.set_third_person(false)
	g.walker.reduced_motion = false
	for study in [1, 0]:
		g.load_trial(study)
		helper.walk(g, Vector3.LEFT if study == 1 else Vector3.RIGHT, 6 if study == 1 else 9)
		var foot: Vector3 = g.walker.foot
		var heading: Vector3 = g.walker.forward
		var support: SurfacePiece = g.walker.support
		var turn_start: Basis = g.overview.global_basis
		var passenger_start: Transform3D = g.walker.avatar.global_transform
		g.architectural = true
		g.rotate_selected(1)
		if not g.busy:
			failures.append("Overview fixture turn must be physically available")
			continue
		for sample_index in range(60):
			if g.busy: g.tween.custom_step(1.0 / 60)
			g.walker.sync_pose(1.0 / 60)
			g.update_camera()
			var up: Vector3 = support.global_basis * support.surface_frame(foot).y
			if g.camera_frame.y.dot(up) < .9999 or not g.overview.global_transform.is_finite():
				failures.append("The overview must stay above the occupied ground")
			if study == 1 and not g.overview.global_basis.is_equal_approx(turn_start):
				failures.append("The overview must not inherit turntable yaw at any animation sample")
			if not g.walker.foot.is_equal_approx(foot) or not g.walker.forward.is_equal_approx(heading):
				failures.append("The overview must not change passenger-local pose")
			if g.walker.avatar.global_position.distance_to(support.to_global(foot)) > .0001:
				failures.append("The passenger must still follow the full carrier transform")
		var angle := rad_to_deg(turn_start.get_rotation_quaternion().angle_to(g.overview.global_basis.get_rotation_quaternion()))
		var expected := 0.0 if study == 1 else 90.0
		if absf(angle - expected) > .05: failures.append("Unexpected ground-relative camera rotation: %s instead of %s" % [angle, expected])
		if g.walker.avatar.global_transform.is_equal_approx(passenger_start): failures.append("Occupied turn must actually move its passenger")
		print("OVERVIEW GROUND TRANSPORT: study=%s camera_degrees=%.3f" % [study + 1, angle])
		var saved: Dictionary = g.snapshot()
		g.restore(saved)
		if g.snapshot() != saved: failures.append("Overview transport must survive exact save/restore")
	g.load_trial(2)
	var unrelated_view: Transform3D = g.overview.global_transform
	helper.turn(g, 1, -1, failures)
	if not g.overview.global_transform.is_equal_approx(unrelated_view): failures.append("Turning another support must not move the overview")
	# Look and view switches are not camera orientation input.
	g.load_trial(0)
	var before: Transform3D = g.overview.global_transform
	g.walker.look(Vector2(125, -50))
	g.toggle_view()
	g.toggle_view()
	if not g.overview.global_transform.is_equal_approx(before): failures.append("Look and Tab must preserve the architectural view")
	# A same-normal seam must not import the receiving piece's local heading.
	g.walker.place(g.world.get_node("Twin_deck/Long_deck"), Vector3.ZERO, Vector3.UP, Vector3.FORWARD)
	g.update_camera()
	var frame: Basis = g.camera_frame
	g.walker.support.basis = g.walker.support.basis * Basis(Vector3.UP, PI / 2)
	g.crossed_seam()
	g.update_camera()
	if not g.camera_frame.is_equal_approx(frame): failures.append("A seam with the same normal must preserve azimuth")
	var antipodal: Basis = g.transport_ground(frame, -frame.y)
	if not antipodal.is_finite() or antipodal.y.dot(-frame.y) < .999: failures.append("An instantaneous antipodal normal needs a finite deterministic fallback")
	g.load_trial(0)
	var initial_view: Transform3D = g.overview.global_transform
	var initial_player: Dictionary = g.walker.snapshot()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	g._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120, 30)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	g._unhandled_input(motion)
	if not g.overview_dragging or g.overview.global_transform.is_equal_approx(initial_view): failures.append("Right-drag must orbit the overview")
	press.pressed = false
	g._input(press)
	if g.overview_dragging: failures.append("Right release must stop dragging even over UI")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	g._unhandled_input(wheel)
	if g.overview_zoom >= 1.0: failures.append("Wheel up must zoom in")
	if g.walker.snapshot() != initial_player: failures.append("Overview controls must not move or turn the character")
	var chosen: Transform3D = g.overview.global_transform
	var chosen_size: float = g.overview.size
	g.toggle_view()
	g._unhandled_input(motion)
	g._unhandled_input(wheel)
	g.toggle_view()
	if not g.overview.global_transform.is_equal_approx(chosen) or g.overview.size != chosen_size:
		failures.append("First-person mouse input and Tab must not overwrite the chosen overview")
	var chosen_save: Dictionary = g.snapshot()
	g.reset_overview()
	g.restore(chosen_save)
	if g.snapshot() != chosen_save: failures.append("Save/restore must preserve the separate orbit layer")
	g.orbit_overview(Vector2(0, 10000))
	g.zoom_overview(100)
	if g.overview_elevation > deg_to_rad(70) + .00001 or g.overview_zoom < .65: failures.append("Orbit and zoom need bounded inspection limits")
	g.orbit_overview(Vector2(0, -10000))
	g.zoom_overview(-100)
	if g.overview_elevation < deg_to_rad(25) - .00001 or g.overview_zoom > 1.4: failures.append("Orbit and zoom need lower/upper bounds")
	var home := InputEventKey.new()
	home.physical_keycode = g.input_bindings.reset_view
	home.pressed = true
	g._unhandled_input(home)
	if not g.overview.global_transform.is_equal_approx(initial_view) or not is_equal_approx(g.overview_zoom, 1.0): failures.append("Reset View must restore recommended framing without restarting the study")
	# A manual choice rides through tilt and stays fixed under turntable yaw.
	for study in [0, 1]:
		g.load_trial(study)
		helper.walk(g, Vector3.RIGHT if study == 0 else Vector3.LEFT, 9 if study == 0 else 6)
		g.orbit_overview(Vector2(80, -12))
		g.zoom_overview(2)
		var saved: Dictionary = g.snapshot()
		var local_camera: Basis = g.camera_frame.inverse() * g.overview.global_basis
		var world_camera: Basis = g.overview.global_basis
		helper.turn(g, 0, 1, failures)
		if study == 1 and not g.overview.global_basis.is_equal_approx(world_camera): failures.append("Turntable must preserve manual view")
		if not (g.camera_frame.inverse() * g.overview.global_basis).is_equal_approx(local_camera): failures.append("Tilt must carry the manual view within the transported frame")
		g.undo()
		if g.snapshot() != saved: failures.append("Undo must restore manual orbit, transport and passenger together")
	# Old saves only carried camera_bias; migrate their actual view directly.
	var legacy: Dictionary = g.snapshot()
	for key in ["camera_frame", "overview_yaw", "overview_elevation", "overview_zoom"]:
		legacy.erase(key)
	g.restore(legacy)
	var ground: Basis = g.walker.support.global_basis * g.walker.support.surface_frame(g.walker.foot)
	if not g.camera_frame.is_equal_approx(ground * legacy.camera_bias) or g.overview_yaw != 0 or g.overview_zoom != 1:
		failures.append("Legacy saves must migrate their original overview framing")
	g.load_trial(0)
	g.walker.reduced_motion = true
	helper.walk(g, Vector3.RIGHT, 9)
	var tilt_before: Basis = g.overview.global_basis
	helper.turn(g, 0, 1, failures)
	if absf(rad_to_deg(tilt_before.get_rotation_quaternion().angle_to(g.overview.global_basis.get_rotation_quaternion())) - 90) > .05:
		failures.append("Reduced-motion tilt must reach the same ground-relative orientation")
	g.walker.reduced_motion = false
	g.load_trial(0)
	g.walker.place(g.start, Vector3(0, .2, 0), Vector3.UP, Vector3.FORWARD)
	g.orbit_overview(Vector2(90, -20))
	var local_orbit: Basis = g.camera_frame.inverse() * g.overview.global_basis
	var previous: Basis = g.overview.global_basis
	for i in range(280):
		g.walker.walk(Vector2(0, -1), 1.0 / 60)
		g.walker.sync_pose(1.0 / 60)
		g.update_camera()
		var up: Vector3 = g.walker.support.global_basis * g.walker.normal
		if g.camera_frame.y.dot(up) < .9999 or not (g.camera_frame.inverse() * g.overview.global_basis).is_equal_approx(local_orbit):
			failures.append("The curve must transport the normal and chosen manual view together")
			break
		if previous.get_rotation_quaternion().angle_to(g.overview.global_basis.get_rotation_quaternion()) > deg_to_rad(3):
			failures.append("Curved traversal or its seam caused an overview heading jump")
			break
		previous = g.overview.global_basis
	if failures.is_empty(): print("OVERVIEW SELF TEST PASS: ground transport, attachment, look, seams, orbit, zoom, input, view switching, reset, undo, save migration")
	g.load_trial(0)
	return failures
