extends RefCounted
## First-person locomotion benchmark on The Ring v3's solved route (docs/designs/2026-10-01-locomotion-pass.md).
## Input is held frame by frame exactly as a player would hold it; the camera is measured every frame.
## Each metric only asserts once it is listed in ASSERTED, so the suite stays green while a
## threshold is still being worked towards; every metric is always reported.
const H = preload("res://tests/test_helpers.gd")
const DT := 1.0 / 60
## Comfort cap the camera's gravity-frame rotation is held to (Normal setting), degrees per second.
const RATE_CAP := 110.0
const THRESHOLDS := {
	"route": 0.0, # failed route segments
	"rate": RATE_CAP * 1.05, # peak gravity-frame rotation, deg/s
	"rate_accel": 2400.0, # peak change of that rotation, deg/s^2: the view eases into a curve
	"roll": .02, # |camera right . ground up| walking straight
	"stalls": 0.0, # held-input dips that recover (snags)
	"mouse": .01, # |1 - camera yaw / mouse yaw| in the ground frame, same frame
	"start": .25, # seconds to 95 % walking speed
	"stop": .2, # metres travelled after release
	"carried": .001, # camera drift relative to a support it rides, after one frame
	"overshoot": .0001, # metres a slide moved beyond the requested step
}
const ASSERTED := ["route", "roll"]

static func run(g: Node3D, failures: Array[String]) -> Dictionary:
	var m := {"route": 0.0, "rate": 0.0, "rate_accel": 0.0, "roll": 0.0, "stalls": 0.0, "overshoot": 0.0}
	route(g, m)
	m.mouse = mouse_ratio(g)
	start_stop(g, m)
	m.carried = carried_drift(g)
	neck_approach(g, m)
	var line := "LOCOMOTION BENCH:"
	for key in THRESHOLDS:
		var value: float = m.get(key, 0.0)
		var over: bool = value > THRESHOLDS[key]
		line += " %s=%.3f%s" % [key, value, "!" if over else ""]
		if over and key in ASSERTED: failures.append("Locomotion %s %.3f exceeds %.3f" % [key, value, THRESHOLDS[key]])
	print(line)
	g.build_level()
	return m

static func piece(g: Node3D, path: String) -> SurfacePiece:
	return g.paths[g.definition.get_node(path)]

static func ground_up(g: Node3D) -> Vector3:
	var w: SurfaceWalker = g.walker
	return (w.support.global_basis * w.support.surface_frame(w.foot).y).normalized()

## Holds one input until the player stops moving (or reaches the goal), measuring every frame.
## Returns the name of the piece the player ends on, or `until` as soon as it is reached.
static func hold(g: Node3D, input: Vector2, m: Dictionary, max_seconds := 20.0, until := "") -> String:
	g.architectural = false
	var w: SurfaceWalker = g.walker
	var travel: Array[float] = []
	var where: Array[String] = []
	var previous_basis: Basis = w.camera.global_basis
	var previous_rate := 0.0
	var still := 0
	for i in range(int(max_seconds / DT)):
		var before: Vector3 = w.support.to_global(w.foot)
		w.walk(input, DT)
		w.sync_pose(DT)
		g.update_camera(DT)
		var moved: float = before.distance_to(w.support.to_global(w.foot))
		travel.append(moved)
		where.append(str(w.support.get_parent().name))
		m.overshoot = maxf(m.overshoot, moved - w.speed * DT * 1.0001)
		var rate: float = rad_to_deg(previous_basis.get_rotation_quaternion().angle_to(w.camera.global_basis.get_rotation_quaternion())) / DT
		m.rate = maxf(m.rate, rate)
		m.rate_accel = maxf(m.rate_accel, absf(rate - previous_rate) / DT)
		previous_rate = rate
		previous_basis = w.camera.global_basis
		m.roll = maxf(m.roll, absf(w.camera.global_basis.x.normalized().dot(ground_up(g))))
		if not g.won and g.reached_goal():
			g._process(0)
			break
		if str(w.support.get_parent().name) == until: break
		still = still + 1 if moved < .0001 else 0
		if still >= 10: break
	# A dip in progress that later recovers is a snag; the final stop at a path end is not.
	for i in range(1, travel.size()):
		if travel[i] < travel[i - 1] * .5:
			for j in range(i + 1, travel.size()):
				if travel[j] > travel[i - 1] * .5:
					m.stalls += 1
					print("LOCOMOTION BENCH: snag on %s (%.3f m after %.3f m)" % [where[i], travel[i], travel[i - 1]])
					break
	return str(w.support.get_parent().name)

static func expect(g: Node3D, m: Dictionary, ended: String, wanted: String) -> void:
	if ended != wanted:
		m.route += 1
		print("LOCOMOTION BENCH: route segment ended on %s, expected %s" % [ended, wanted])

## Returning to first person after a turn (Tab) settles the view on the carried pose.
static func back_to_first_person(g: Node3D) -> void:
	g.walker.sync_pose(1.0)

## The solved route, one held key per walk. Headings change only at the route's decision points.
static func route(g: Node3D, m: Dictionary) -> void:
	var failures: Array[String] = []
	var inner := rig(g, "InnerWheel")
	var ring := rig(g, "Ring")
	g.restart()
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	g.walker.forward = Vector3.RIGHT
	back_to_first_person(g)
	# Entry -> ring arm -> inner arm -> upper door -> curl -> upside down at the lower door.
	expect(g, m, hold(g, Vector2(0, -1), m), "TowerUnder")
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	back_to_first_person(g)
	# Out of the lower door onto the underside arm, then the ring's underside.
	expect(g, m, hold(g, Vector2(0, -1), m), "RingUnder")
	H.turn(g, ring, 1, failures); H.turn(g, ring, 1, failures)
	g.walker.forward = Vector3.RIGHT
	back_to_first_person(g)
	# Balcony underside -> terrace curve -> terrace.
	expect(g, m, hold(g, Vector2(0, -1), m), "Terrace")
	if not g.won: m.route += 1
	m.route += failures.size()

static func rig(g: Node3D, name: String) -> int:
	for i in range(g.rigs.size()):
		if g.rigs[i].node.name == name: return i
	return -1

## Mid-curl, a mouse movement must turn the view by exactly its yaw, measured about the
## ground normal so the curve's own rotation cannot hide or fake an error.
static func mouse_ratio(g: Node3D) -> float:
	var w: SurfaceWalker = g.walker
	var curl := piece(g, "TowerCurl")
	g.architectural = false
	w.place(curl, curl.point_at(curl.length() * .4), curl.surface_frame(curl.point_at(curl.length() * .4)).y, -curl.surface_frame(curl.point_at(curl.length() * .4)).z)
	for i in range(30): w.sync_pose(DT)
	var up := ground_up(g)
	var before: Vector3 = (-w.camera.global_basis.z).slide(up).normalized()
	var mouse := 120.0
	w.look(Vector2(mouse, 0))
	w.sync_pose(DT)
	var after: Vector3 = (-w.camera.global_basis.z).slide(up).normalized()
	var turned := before.signed_angle_to(after, up)
	return absf(1.0 - turned / (-mouse * w.sensitivity))

## Time to reach 95 % speed on flat ground, and the distance covered after release.
static func start_stop(g: Node3D, m: Dictionary) -> void:
	var w: SurfaceWalker = g.walker
	g.restart()
	g.architectural = false
	w.forward = Vector3.RIGHT
	m.start = INF
	for i in range(60):
		var before: Vector3 = w.support.to_global(w.foot)
		w.walk(Vector2(0, -1), DT)
		if before.distance_to(w.support.to_global(w.foot)) >= w.speed * DT * .95:
			m.start = i * DT
			break
	var released: Vector3 = w.support.to_global(w.foot)
	for i in range(60): w.walk(Vector2.ZERO, DT)
	m.stop = released.distance_to(w.support.to_global(w.foot))

## Riding a turn must carry the first-person view with the support: no easing back towards the
## old world orientation on the first frame afterwards.
static func carried_drift(g: Node3D) -> float:
	var failures: Array[String] = []
	var w: SurfaceWalker = g.walker
	g.restart()
	w.forward = Vector3.RIGHT
	var scratch := {"route": 0.0, "rate": 0.0, "rate_accel": 0.0, "roll": 0.0, "stalls": 0.0, "overshoot": 0.0}
	hold(g, Vector2(0, -1), scratch, 5.0, "RingTop")
	hold(g, Vector2(0, -1), scratch, .4)
	for i in range(60): w.sync_pose(DT)
	var before: Transform3D = w.support.global_transform.affine_inverse() * w.camera.global_transform
	H.turn(g, rig(g, "Ring"), 1, failures)
	w.sync_pose(DT)
	var after: Transform3D = w.support.global_transform.affine_inverse() * w.camera.global_transform
	return maxf(before.origin.distance_to(after.origin), before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion()))

## Walking off-centre and diagonally from the inner arm into its narrow neck must not snag.
static func neck_approach(g: Node3D, m: Dictionary) -> void:
	var failures: Array[String] = []
	var inner := rig(g, "InnerWheel")
	g.restart()
	H.turn(g, inner, 1, failures); H.turn(g, inner, 1, failures)
	var arm := piece(g, "InnerWheel/InnerTop")
	g.walker.place(arm, Vector3(.2, arm.half.y, .6), Vector3.UP, Vector3(-1, 0, -.35).normalized())
	expect(g, m, hold(g, Vector2(0, -1), m, 3.0, "TowerTop"), "TowerTop")
	m.route += failures.size()
