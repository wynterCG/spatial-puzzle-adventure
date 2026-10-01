extends RefCounted

static func run(g: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var largest_jump := 0.0
	var largest_angle := 0.0
	g.walker.third_person = true
	g.walker.keep_world_horizon = true
	g.walker.reduced_motion = false
	for settings in [[0.0, .42, 5.5], [PI / 2, .42, 5.5], [PI, .42, 5.5], [-PI / 2, .42, 5.5], [0.0, .12, 3.0], [0.0, 1.0, 8.0], [PI / 2, .12, 8.0], [-PI / 2, 1.0, 3.0]]:
		g.load_trial(0)
		g.walker.orbit_pitch = settings[1]
		g.walker.camera_distance = settings[2]
		g.walker.camera_initialized = false
		g.walker.world_orbit_initialized = false
		g.walker.place(g.start, Vector3(0, .2, 0), Vector3.UP, Vector3.FORWARD)
		g.walker.orbit_yaw = settings[0]
		g.walker.camera_initialized = false
		g.walker.sync_pose(1)
		var previous: Transform3D = g.walker.camera.global_transform
		for i in range(280):
			g.walker.walk(Vector2(0, -1), 1.0 / 60)
			g.walker.sync_pose(1.0 / 60)
			var current: Transform3D = g.walker.camera.global_transform
			var requested_back: Vector3 = -g.walker.world_orbit_heading.rotated(Vector3.UP, g.walker.orbit_yaw)
			if current.basis.z.slide(Vector3.UP).normalized().dot(requested_back) < .999:
				failures.append("Obstacles must not take over the mouse-controlled azimuth")
				break
			largest_jump = maxf(largest_jump, previous.origin.distance_to(current.origin))
			largest_angle = maxf(largest_angle, rad_to_deg(previous.basis.get_rotation_quaternion().angle_to(current.basis.get_rotation_quaternion())))
			if not current.is_finite() or current.basis.y.dot(Vector3.UP) < .5:
				failures.append("World camera must retain an upright screen without pole flips")
				break
			previous = current
			if settings[0] == 0.0 and settings[2] == 5.5 and i == 135:
				if g.walker.arm_length < 3.0:
					failures.append("The curved wall must not squash third person into the avatar")
				g.walker.update_overview_visibility(g.overview, false)
				var curve: Node3D = g.world.get_node("Rounded_path")
				var faded := 0
				for solid in curve.solid_meshes:
					if solid.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						faded += 1
				if faded == 0 or faded >= curve.solid_meshes.size():
					failures.append("Only the occluding part of the curve should become translucent")
				g.walker.update_overview_visibility(g.overview, true)
				for solid in curve.solid_meshes:
					if solid.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						failures.append("Isometric view must restore the complete opaque track")
						break
	if largest_jump > .65 or largest_angle > 8.0:
		failures.append("Curve camera snaps: %.3f units / %.3f degrees in one 60 Hz frame" % [largest_jump, largest_angle])
	print("CAMERA CONTINUITY: max %.3f units / %.3f degrees per 60 Hz frame" % [largest_jump, largest_angle])
	# Exercise the real input-to-camera alignment, including releases, a pitch
	# adjustment and walking against the far boundary without reversing W.
	for interrupted in [false, true]:
		g.load_trial(0)
		g.walker.orbit_pitch = .42
		g.walker.camera_distance = 5.5
		g.walker.camera_initialized = false
		g.walker.world_orbit_initialized = false
		g.walker.orbit_changed = false
		g.walker.place(g.start, Vector3(0, .2, 0), Vector3.UP, Vector3.FORWARD)
		for i in range(360):
			if interrupted and i == 120:
				g.walker.look(Vector2(0, 15))
			if interrupted and i == 135:
				var before_look: Vector3 = g.walker.forward
				g.walker.look(Vector2(10, 0))
				g.walker.align_movement_to_camera(Vector2(0, -1))
				if before_look.dot(g.walker.forward) < .99:
					failures.append("A small mouse yaw must not reverse forward on a wall")
				g.walker.look(Vector2(-10, 0))
			if interrupted and i == 160:
				var before_switch: Transform3D = g.walker.camera.global_transform
				g.toggle_view()
				g.toggle_view()
				if not g.walker.camera.global_transform.is_equal_approx(before_switch):
					failures.append("View toggles must not snap the third-person arm")
			if interrupted and i == 190:
				var before_mode: Vector3 = g.walker.forward
				g.walker.set_third_person(false)
				g.walker.set_third_person(true)
				g.walker.align_movement_to_camera(Vector2(0, -1))
				if before_mode.dot(g.walker.forward) < .999:
					failures.append("Returning from first person must preserve forward on the curve")
			var movement := Vector2.ZERO if interrupted and i % 20 == 19 else Vector2(0, -1)
			g.walker.align_movement_to_camera(movement)
			g.walker.walk(movement, 1.0 / 60)
			g.walker.sync_pose(1.0 / 60)
		if g.walker.support.name != "Lower_landing":
			failures.append("Real W input must finish the curved path and stay on the landing; interrupted=%s" % interrupted)
		for i in range(360):
			g.walker.align_movement_to_camera(Vector2(0, 1))
			g.walker.walk(Vector2(0, 1), 1.0 / 60)
			g.walker.sync_pose(1.0 / 60)
		if g.walker.support != g.start:
			failures.append("S must return along the same curve without remapping the controls")
	# Reproduce the reported live-state regression: a stale transported heading
	# on an ordinary platform must not make W move sideways to the visible view.
	g.load_trial(0)
	for part in [g.start, g.world.get_node("Lower_landing")]:
		for yaw in [0.0, PI / 2, PI, -PI / 2]:
			g.walker.camera_initialized = false
			g.walker.world_orbit_initialized = false
			g.walker.place(part, Vector3(0, .2, 0), Vector3.UP, Vector3.FORWARD)
			g.walker.orbit_yaw = yaw
			g.walker.camera_initialized = false
			g.walker.sync_pose(1)
			for movement in [Vector2(0, -1), Vector2(1, 0)]:
				g.walker.foot = Vector3(0, .2, 0)
				g.walker.forward = Vector3.RIGHT
				g.walker.movement_frame_initialized = true
				g.walker.last_walk_input = Vector2.ZERO
				g.walker.align_movement_to_camera(movement)
				var before: Vector3 = part.to_global(g.walker.foot)
				g.walker.walk(movement, 1.0 / 60)
				var displacement: Vector3 = part.to_global(g.walker.foot) - before
				var ground_up: Vector3 = part.global_basis * Vector3.UP
				var expected: Vector3 = (g.walker.camera.global_basis.y if movement.y < 0 else g.walker.camera.global_basis.x).slide(ground_up).normalized()
				if displacement.normalized().dot(expected) < .99:
					failures.append("Fresh W/D input must match the screen on ordinary ground, including the underside")
			# Mouse look while standing still must not rotate the avatar or leave
			# a stale independently integrated movement yaw behind it.
			g.walker.walk(Vector2.ZERO, 1.0 / 60)
			var heading_before: Vector3 = g.walker.forward
			g.walker.look(Vector2(200, 0))
			if not g.walker.forward.is_equal_approx(heading_before):
				failures.append("Mouse orbit must not steer a stationary avatar")
			g.walker.align_movement_to_camera(Vector2(0, -1))
			var expected_forward: Vector3 = g.walker.camera.global_basis.y.slide(part.global_basis.y).normalized()
			if (part.global_basis * g.walker.forward).dot(expected_forward) < .99:
				failures.append("Starting after a mouse orbit must use the new visible view")
	return failures
