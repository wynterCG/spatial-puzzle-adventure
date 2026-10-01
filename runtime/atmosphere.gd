extends RefCounted
## World atmosphere (docs/designs/2026-10-01-monumental-scale.md): a sky gradient, depth fog
## and a low mist give monuments depth and a vast surrounding void. Works in Compatibility.

static func world_environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0b1226")
	sky_material.sky_horizon_color = Color("3a4766")
	sky_material.ground_horizon_color = Color("3a4766")
	sky_material.ground_bottom_color = Color("1a2238")
	sky_material.sun_angle_max = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5b8ef")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("44516f")
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 1600.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = .6
	# Mist far below: the void has depth, never a floor.
	env.fog_height = -60.0
	env.fog_height_density = .02
	return env

## The isometric view keeps its puzzle crisp: haze begins beyond the composition.
static func overview_environment(world: Environment, camera_distance: float) -> Environment:
	var env: Environment = world.duplicate()
	env.fog_depth_begin = camera_distance + 150.0
	env.fog_depth_end = camera_distance + 2400.0
	return env
