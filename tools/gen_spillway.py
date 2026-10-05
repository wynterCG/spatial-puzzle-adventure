"""Generates monuments/the_spillway.tscn: The Spillway (docs/designs/2026-10-02-the-spillway.md).
The scene is data; edit it here, not by hand. Run from anywhere: python tools/gen_spillway.py

A reservoir hangs in the void. Its sluice Drum (a gate rolling about X, set in the west wall)
bridges the intake to the keeper's landing and turns over whoever stands on it. Its Weir Arm (a
gantry swinging about Y from the Crown round the spillway throat) meets the landing's underside
and the north gallery top and bottom. The Crown's keeper's gate leads down the throat's east wall
to the basin's underside and the Sanctuary. Directions: west is -x, north is -z. Everything below
is at x1 and built at SCALE; player-sized details (lamps, rails, trims) are in metres.
"""
import math, pathlib

SCALE = 4
PI = math.pi

def g(x): return x * SCALE
def num(x): return '%g' % x
def v3(x, y, z): return 'Vector3(%g, %g, %g)' % (x, y, z)
def p3(x, y, z): return v3(g(x), g(y), g(z))
def rect(x, z, w, d): return 'Rect2(%g, %g, %g, %g)' % (g(x), g(z), g(w), g(d))
def col(r, gg, b, a=1): return 'Color(%g, %g, %g, %g)' % (r, gg, b, a)
def hexcol(h, a=1): return col(int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)
def xform(x_axis, y_axis, z_axis, origin):
    """Transform3D text from basis columns (local x, y, z in world) and an x1 origin."""
    rows = [(x_axis[i], y_axis[i], z_axis[i]) for i in range(3)]
    return 'Transform3D(%s, %s)' % (', '.join('%g' % v for row in rows for v in row), ', '.join('%g' % g(v) for v in origin))

res = []
def sub(t, i, **props):
    body = '\n'.join('%s = %s' % (k, v) for k, v in props.items())
    res.append('[sub_resource type="%s" id="%s"]\n%s\n' % (t, i, body))

nodes = []
def node(name, parent, typ='Node3D', script=None, **props):
    head = '[node name="%s" type="%s" parent="%s"]' % (name, typ, parent) if parent is not None else '[node name="%s" type="%s"]' % (name, typ)
    lines = [head]
    if script: lines.append('script = ExtResource("%s")' % script)
    lines += ['%s = %s' % (k, v) for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')
def comp(name, parent, **props): node(name, parent, script='3', **props)
def mesh(name, parent, mesh_id, material, shadow=False, **props):
    if not shadow: props['cast_shadow'] = 0
    node(name, parent, 'MeshInstance3D', mesh='SubResource("%s")' % mesh_id, material_override='SubResource("%s")' % material, **props)
def geometry(name, parent, lo, hi, tint):
    """A box GEOMETRY component spanning x1 corners lo..hi (line of sight and the eye see it)."""
    comp(name, parent, kind=8, position=p3(*[(a + b) / 2 for a, b in zip(lo, hi)]), dimensions=p3(*[b - a for a, b in zip(lo, hi)]), tint=tint)

# --- Palette (design section 13): colour regions, not a puzzle code ---------------------------
CHARCOAL = hexcol('26282c'); SHELL = hexcol('34363b'); IVORY = hexcol('e8e1cf'); TEAL = hexcol('4a8786')
CORAL = hexcol('d06a52'); AMBER = hexcol('f2a541'); BRONZE = hexcol('5a4a3a')
def emissive(i, h, energy):
    c = hexcol(h)
    sub('StandardMaterial3D', i, albedo_color=c, emission_enabled='true', emission=c, emission_energy_multiplier=energy)
def flat(i, h, rough=.8, metal=0):
    sub('StandardMaterial3D', i, albedo_color=hexcol(h), roughness=rough, metallic=metal)
emissive('Amber', 'f2a541', 2.6)
emissive('PathLamp', 'ffd9a0', 2.2)      # path lamps: squat, warm, perpendicular to a walkable surface
emissive('Pendant', 'e8f2ff', 2.0)       # world-gravity lamps: slender, cool, on chains
emissive('Lantern', 'ffb35c', 2.4)
emissive('TealGlow', '6fd3cf', 1.4)      # accent on what turns (the Crown and Arm)
emissive('CoralGlow', 'ff8a6b', 1.4)     # accent on what turns (the Drum)
flat('Chain', '3a3c40', .5, .6)
flat('Vine', '35503f', .95)
flat('Rail', '9a978e', .5, .4)
flat('Bollard', '4a4740', .6, .3)
flat('TowerMat', '2c3442', .9)
sub('StandardMaterial3D', 'StillWater', albedo_color=col(.24, .46, .48, .78), transparency=1, roughness=.08, metallic=.3, cull_mode=2)
sub('StandardMaterial3D', 'MistMat', albedo_color=col(.92, .96, 1, .35), transparency=1, shading_mode=0)
sub('StandardMaterial3D', 'DripMat', albedo_color=col(.75, .9, 1, .8), transparency=1, shading_mode=0)
# Falling water: a scrolling translucent shader (world/water.gdshader), several strengths.
def falls_material(i, alpha, speed, streaks):
    sub('ShaderMaterial', i, shader='ExtResource("4")', **{'shader_parameter/colour': col(.78, .92, .95, alpha), 'shader_parameter/speed': num(speed), 'shader_parameter/streaks': num(streaks)})
falls_material('Falls', .8, 1.6, 9)
falls_material('Sheet', .55, 1.1, 14)
falls_material('Rush', .7, 2.4, 22)

# Shared meshes.
sub('CylinderMesh', 'BollardMesh', top_radius=.16, bottom_radius=.2, height=.9, radial_segments=10)
sub('SphereMesh', 'BollardCap', radius=.17, height=.22, radial_segments=10, rings=4)
sub('CylinderMesh', 'ChainMesh', top_radius=.04, bottom_radius=.04, height=1, radial_segments=5)
sub('SphereMesh', 'PendantMesh', radius=.45, height=.9, radial_segments=12, rings=6)
sub('CylinderMesh', 'VineMesh', top_radius=.07, bottom_radius=.03, height=1, radial_segments=4)
sub('BoxMesh', 'LanternMesh', size=p3(.6, .6, .6))
sub('BoxMesh', 'PlateMesh', size=v3(g(1.2), .04, g(1.2)))
sub('SphereMesh', 'MistDot', radius=.9, height=1.8, radial_segments=12, rings=6, material='SubResource("MistMat")')
sub('SphereMesh', 'DripDot', radius=.06, height=.24, radial_segments=4, rings=2, material='SubResource("DripMat")')

def basis_for(normal):
    """Rotation (Euler) that turns a mesh's +y onto one of the six axis normals."""
    return {(0, 1, 0): v3(0, 0, 0), (0, -1, 0): v3(PI, 0, 0), (-1, 0, 0): v3(0, 0, PI / 2), (1, 0, 0): v3(0, 0, -PI / 2),
            (0, 0, 1): v3(PI / 2, 0, 0), (0, 0, -1): v3(-PI / 2, 0, 0)}[normal]

lamp_count = [0]
def path_lamp(parent, at, normal):
    """A squat warm bollard standing perpendicular to a walkable surface (x1 surface point)."""
    lamp_count[0] += 1
    name = 'PathLamp%02d' % lamp_count[0]
    base = [g(a) for a in at]
    centre = [base[i] + normal[i] * .45 for i in range(3)]
    node(name, parent, position=v3(*centre), rotation=basis_for(normal))
    mesh('Post', '%s/%s' % (parent, name), 'BollardMesh', 'Bollard')
    mesh('Light', '%s/%s' % (parent, name), 'BollardCap', 'PathLamp', position=v3(0, .5, 0))

hang_count = [0]
def pendant(parent, at, length):
    """A cool lamp on a long chain, hanging toward true world-down from an x1 point."""
    hang_count[0] += 1
    name = 'Pendant%02d' % hang_count[0]
    top = [g(a) for a in at]
    node(name, parent, position=v3(*top))
    mesh('Chain', '%s/%s' % (parent, name), 'ChainMesh', 'Chain', position=v3(0, -length / 2, 0), scale=v3(1, length, 1))
    mesh('Lamp', '%s/%s' % (parent, name), 'PendantMesh', 'Pendant', position=v3(0, -length - .45, 0))

vine_count = [0]
def vine(parent, at, length):
    vine_count[0] += 1
    top = [g(a) for a in at]
    mesh('Vine%03d' % vine_count[0], parent, 'VineMesh', 'Vine', position=v3(top[0], top[1] - length / 2, top[2]), scale=v3(1, length, 1))

def particles(name, parent, at, extents, amount, lifetime, gravity, dot, speed=(0, .5)):
    node(name, parent, 'CPUParticles3D', position=p3(*at), amount=amount, lifetime=num(lifetime), mesh='SubResource("%s")' % dot,
         emission_shape=3, emission_box_extents=v3(*[g(e) for e in extents]), direction=v3(0, -1, 0), spread=num(8),
         gravity=v3(0, -gravity, 0), initial_velocity_min=num(speed[0]), initial_velocity_max=num(speed[1]), local_coords='false')

def water_quad(name, parent, size, at, normal, material):
    """A vertical or horizontal sheet of water (QuadMesh faces +z; turned onto `normal`)."""
    sub('QuadMesh', name + 'Mesh', size='Vector2(%g, %g)' % (g(size[0]), g(size[1])))
    rot = {(1, 0, 0): v3(0, PI / 2, 0), (-1, 0, 0): v3(0, -PI / 2, 0), (0, 0, 1): v3(0, 0, 0), (0, 0, -1): v3(0, PI, 0), (0, 1, 0): v3(-PI / 2, 0, 0)}[normal]
    mesh(name, parent, name + 'Mesh', material, position=p3(*at), rotation=rot)

def state_art(name, parent, structure, states):
    node(name, parent, script='5', structure='NodePath("%s")' % structure, states='PackedInt32Array(%s)' % ', '.join(str(s) for s in states))

QUESTION = "How do you get under the reservoir?"
EXPLANATION = ("Stand on the sluice drum and roll it over: it carries you underneath the keeper's landing, where the weir arm's "
               "underside meets you if it was swung west. Ride the arm north hanging beneath it, wrap round the north gallery onto its "
               "top, board the same arm from above and swing it west again: now the crown's keeper's gate stands over the throat stair. "
               "Walk down inside the spillway and out under the basin to the sanctuary.")
HINTS = ["Lamps stand on any surface you can walk, even upside down. Which undersides have lamps?",
         "The drum is a gate that rolls. Stand on its deck when you roll it.",
         "Swing the arm west, roll yourself under the landing, ride the arm north beneath it, wrap onto the north gallery, board the arm on top and swing it west again: then take the keeper's gate down the throat."]

node('Puzzle', None, script='1')
node('Level', '.', script='2',
     level_id='"the_spillway"', revision=1, title='"The spillway"',
     question='"%s"' % QUESTION, explanation='"%s"' % EXPLANATION,
     overview_focus=p3(-2, -7, 0), overview_size=num(g(40)),
     overview_azimuth_degrees=-52, overview_elevation_degrees=32,
     sweep_tolerance=num(.04 * SCALE),
     hints='PackedStringArray(%s)' % ', '.join('"%s"' % h for h in HINTS))

# --- Intake terrace (start, west): the incoming aqueduct's walkway, widening to a platform ----
INTAKE_Y = 1.5
comp('Intake', 'Level', kind=0, label='"Intake terrace"', position=p3(-16.9, INTAKE_Y, 0), dimensions=p3(10.2, .8, 5.2), end_sockets='false', tint=IVORY,
     regions='Array[Rect2]([%s, %s])' % (rect(-1.1, -1.2, 6.2, 2.4), rect(-5.1, -1.2, 4.0, 5.2)))
comp('DrumSocket', 'Level/Intake', kind=2, position=p3(5.1, 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=num(g(2.4)))
# The start stands at the platform's east edge: past it the gaze drops under the basin to the
# falls and the Sanctuary's spire (a deck in front would hide everything below the horizon).
comp('PlayerStart', 'Level/Intake', kind=4, position=p3(-1.4, 0, 3.0), path='NodePath("..")', forward=v3(1, 0, 0))
geometry('IntakePier', 'Level', (-21.5, -60, -.6), (-19.5, INTAKE_Y - .8, 3.4), SHELL)
geometry('LanternPost', 'Level', (-21.6, INTAKE_Y, 4.25), (-21.4, INTAKE_Y + 3.2, 4.45), SHELL)
mesh('Lantern', 'Level/LanternPost', 'LanternMesh', 'Lantern', position=p3(0, 1.9, 0))
for x in (-21, -19, -17, -15, -13):
    path_lamp('Level', (x, INTAKE_Y, -1.25), (0, 1, 0))
# The aqueduct channel alongside the walkway, coming from the far west and ending at the gate.
geometry('ChannelFloor', 'Level', (-90, INTAKE_Y - 1.4, -2.8), (-11.8, INTAKE_Y - .8, -1.2), SHELL)
geometry('ChannelWall', 'Level', (-90, INTAKE_Y - 1.4, -3.0), (-11.8, INTAKE_Y - .2, -2.8), SHELL)
water_quad('ChannelWater', 'Level', (78.2, 1.6), (-50.9, INTAKE_Y - .85, -2.0), (0, 1, 0), 'Sheet')
for i, x in enumerate(range(-86, -20, 12)):
    geometry('AqueductPier%d' % i, 'Level', (x - .6, -60, -2.8), (x + .6, INTAKE_Y - 1.4, -1.2), SHELL)

# --- Sluice house and Drum (west wall) ----------------------------------------------------------
# The Drum rolls about X. Its deck and keel are opposite faces 3.1 apart round an axis at y -0.05,
# so with either face up it bridges intake (+1.5) to landing (+1.5), and the face below meets the
# landing's underside (-1.6).
DRUM_X = (-11.8, -8.2); AXIS_Y = -.05; HALF = 1.55
dmid = (DRUM_X[0] + DRUM_X[1]) / 2; dlen = DRUM_X[1] - DRUM_X[0]
comp('Drum', 'Level', kind=3, label='"The sluice drum"', position=p3(dmid, AXIS_Y, 0), axis=v3(1, 0, 0), initial_state=0, duration=2.2, tint=CORAL)
comp('DrumDeck', 'Level/Drum', kind=0, label='"Drum deck"', position=p3(0, HALF, 0), dimensions=p3(dlen, .8, 2.4), tint=CORAL)
comp('DrumKeel', 'Level/Drum', kind=0, label='"Drum keel"', position=p3(0, -HALF, 0), rotation=v3(PI, 0, 0), dimensions=p3(dlen, .8, 2.4), tint=CORAL)
comp('DrumCore', 'Level/Drum', kind=8, position=p3(0, 0, 0), dimensions=p3(dlen, 2 * HALF - 1.6, 2.4), tint=CORAL)
# Gate detailing: sluice slots on the side faces, rails on the deck, inspection lamps on the keel.
sub('BoxMesh', 'DrumSlot', size=v3(g(dlen) - 2, g(.5), .1))
for k, z in (('SlotNorth', -1.2), ('SlotSouth', 1.2)):
    mesh(k, 'Level/Drum', 'DrumSlot', 'CoralGlow', position=v3(0, 0, g(z) + (.06 if z > 0 else -.06)))
sub('BoxMesh', 'DrumRail', size=v3(g(dlen) - .4, .06, .06))
for k, y, z in (('DeckRailN', 1, -1), ('DeckRailS', 1, 1), ('KeelRailN', -1, -1), ('KeelRailS', -1, 1)):
    mesh(k, 'Level/Drum', 'DrumRail', 'Rail', position=v3(0, y * (g(HALF) + 1.0), z * (g(1.2) - .05)))
for x in (-1.2, 1.2):
    for z in (-1.25, 1.25):
        path_lamp('Level/Drum', (x, HALF, z), (0, 1, 0))
        path_lamp('Level/Drum', (x, -HALF, z), (0, -1, 0))
# Bearing collars and housings: the axle lives in the sluice house walls.
sub('TorusMesh', 'CollarMesh', inner_radius=num(g(2.55)), outer_radius=num(g(2.9)), rings=48, ring_segments=8)
for k, x in (('CollarWest', DRUM_X[0] - .15), ('CollarEast', -9.05)):
    mesh(k, 'Level', 'CollarMesh', 'Rail', shadow=True, position=p3(x, AXIS_Y, 0), rotation=v3(0, 0, PI / 2))
for k, z0, z1 in (('HousingNorth', -3.9, -2.95), ('HousingSouth', 2.95, 3.9)):
    geometry(k, 'Level', (DRUM_X[0], -2.6, z0), (-8.2, 3.2, z1), SHELL)

# Keeper's landing: top +1.5 (viewpoint), underside -1.6 (meets the Arm's underside).
LAND_X = (-8.2, -6.6)
lmid = (LAND_X[0] + LAND_X[1]) / 2
comp('Landing', 'Level', kind=0, label='"Keeper\'s landing"', position=p3(lmid, INTAKE_Y, 0), dimensions=p3(1.6, .8, 2.4), end_sockets='false', tint=IVORY)
comp('DrumSocket', 'Level/Landing', kind=2, position=p3(-.8, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(2.4)))
comp('LandingUnder', 'Level', kind=0, label='"Under the landing"', position=p3(lmid, -1.6, 0), rotation=v3(PI, 0, 0), dimensions=p3(1.6, .8, 2.4), end_sockets='false', tint=IVORY)
comp('DrumSocket', 'Level/LandingUnder', kind=2, position=p3(-.8, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(2.4)))
comp('ArmSocket', 'Level/LandingUnder', kind=2, position=p3(.8, 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=num(g(.8)))
geometry('LandingCore', 'Level', (LAND_X[0], -.8, -1.2), (LAND_X[1], INTAKE_Y - .8, 1.2), SHELL)
for z in (-1.25, 1.25):
    path_lamp('Level', (-6.8, INTAKE_Y, z), (0, 1, 0))
    path_lamp('Level', (-6.8, -1.6, z), (0, -1, 0))

# --- Basin (fixed): walls, floor, throat ------------------------------------------------------
B_OUT, B_IN, WALL_TOP, FLOOR = 9, 8.2, .4, (-6, -4)
NOTCH_Z, NOTCH_Y = 2.6, -2.1
FB = FLOOR[0] + .02   # the shell's underside sits just above the walkable underside path
geometry('WallNorth', 'Level', (-B_OUT, FB, -B_OUT), (B_OUT, WALL_TOP, -B_IN), CHARCOAL)
geometry('WallSouth', 'Level', (-B_OUT, FB, B_IN), (B_OUT, WALL_TOP, B_OUT), CHARCOAL)
geometry('WallEast', 'Level', (B_IN, FB, -B_IN), (B_OUT, WALL_TOP, B_IN), CHARCOAL)
geometry('WallWestNorth', 'Level', (-B_OUT, FB, -B_IN), (-B_IN, WALL_TOP, -NOTCH_Z), CHARCOAL)
geometry('WallWestSouth', 'Level', (-B_OUT, FB, NOTCH_Z), (-B_IN, WALL_TOP, B_IN), CHARCOAL)
geometry('WallWestSill', 'Level', (-B_OUT, FB, -NOTCH_Z), (-B_IN, NOTCH_Y, NOTCH_Z), CHARCOAL)
T_IN, T_OUT, T_TOP = 1.2, 1.8, -1.62
geometry('FloorNorth', 'Level', (-B_IN, FB, -B_IN), (B_IN, FLOOR[1], -T_OUT), CHARCOAL)
geometry('FloorSouth', 'Level', (-B_IN, FB, T_OUT), (B_IN, FLOOR[1], B_IN), CHARCOAL)
geometry('FloorWest', 'Level', (-B_IN, FB, -T_OUT), (-T_OUT, FLOOR[1], T_OUT), CHARCOAL)
geometry('FloorEast', 'Level', (T_OUT, FB, -T_OUT), (B_IN, FLOOR[1], T_OUT), CHARCOAL)
# The east wall stops above the bottom curl, which wraps its lower edge (x 1.2 -> 1.7).
geometry('ThroatEast', 'Level', (T_IN, -5.5, -T_OUT), (T_OUT, T_TOP, T_OUT), CHARCOAL)
geometry('ThroatEastFoot', 'Level', (T_IN + .5, FB, -T_OUT), (T_OUT, -5.5, T_OUT), CHARCOAL)
geometry('ThroatWest', 'Level', (-T_OUT, FB, -T_OUT), (-T_IN, T_TOP, T_OUT), CHARCOAL)
geometry('ThroatNorth', 'Level', (-T_IN, FB, -T_OUT), (T_IN, T_TOP, -T_IN), CHARCOAL)
geometry('ThroatSouth', 'Level', (-T_IN, FB, T_IN), (T_IN, T_TOP, T_OUT), CHARCOAL)
# Still water round the throat (y -3.5): a ceiling when you are upside down.
for k, size, at in (('WaterNorth', (16.4, 6.4), (0, -3.5, -5)), ('WaterSouth', (16.4, 6.4), (0, -3.5, 5)),
                    ('WaterWest', (6.4, 3.6), (-5, -3.5, 0)), ('WaterEast', (6.4, 3.6), (5, -3.5, 0))):
    sub('PlaneMesh', k + 'Mesh', size='Vector2(%g, %g)' % (g(size[0]), g(size[1])))
    mesh(k, 'Level', k + 'Mesh', 'StillWater', position=p3(*at))
# The falls: fed through ports under the Crown, down the throat and far into the mist.
sub('CylinderMesh', 'FallsMesh', top_radius=num(g(.45)), bottom_radius=num(g(.6)), height=num(g(58)), radial_segments=16)
mesh('Falls', 'Level', 'FallsMesh', 'Falls', position=p3(0, -1.6 - 29, 0))
for k, z in (('OverflowNorth', -4.5), ('OverflowSouth', 4.5)):
    water_quad(k, 'Level', (4, 34), (B_OUT + .03, WALL_TOP - 17, z), (1, 0, 0), 'Sheet')
particles('ThroatMist', 'Level', (0, -7, 0), (1.6, .5, 1.6), 70, 9, 2.5, 'MistDot', (1, 3))
particles('FallsSpray', 'Level', (0, -16, 0), (3, 4, 3), 60, 10, 2, 'MistDot', (0, 1))
particles('UnderDrips', 'Level', (2, -6.05, 0), (6, 0, 6), 50, 3, 9.8, 'DripDot')
for x in range(-8, 9, 2):
    for z, sign in ((-B_OUT + .2, 1), (B_OUT - .2, -1)):
        vine('Level', (x + .3 * sign, FLOOR[0], z), g(1.5 + ((x * 7 + z * 3) % 5) * 1.6))
for z in range(-6, 7, 3):
    vine('Level', (-B_OUT + .2, FLOOR[0], z + .7), g(2 + (z * 5 % 4) * 1.5))
for x, z, length in ((-5, -5, 30), (-1, 5.5, 38), (3, -5.5, 26), (-6, 3, 34)):
    pendant('Level', (x, FLOOR[0], z), length)

# --- Throat stair (fixed): east inner wall, from under the Crown (-1.6) to the bottom rim --------
# Its local x runs down the wall, its ground faces -x (into the throat).
STAIR_TOP, STAIR_BOTTOM, R = -1.6, -5.5, .5
smid = (STAIR_TOP + STAIR_BOTTOM) / 2
comp('ThroatStair', 'Level', kind=0, label='"Throat stair"', transform=xform((0, -1, 0), (-1, 0, 0), (0, 0, -1), (T_IN, smid, 0)),
     dimensions=p3(STAIR_TOP - STAIR_BOTTOM, .3, 1.6), tint=IVORY)
# Round the bottom rim onto the basin's underside: forward is down, ground faces -x.
comp('ThroatRim', 'Level', kind=1, label='"Throat rim"', transform=xform((0, 0, -1), (-1, 0, 0), (0, 1, 0), (T_IN, STAIR_BOTTOM, 0)),
     radius=num(g(R)), arc_degrees='"90"', dimensions=p3(2, .26, 1.6), tint=IVORY)
for y in (-2.2, -3.2, -4.2, -5.0):
    for z in (-.85, .85):
        path_lamp('Level', (T_IN, y, z), (-1, 0, 0))
# The stair head: an amber band across the wall where the keeper's gate must come to rest.
# Readable from the Crown across the throat: a broad band and amber edges running down the stair.
sub('BoxMesh', 'StairHeadMesh', size=v3(.08, g(.22), g(1.9)))
mesh('StairHead', 'Level', 'StairHeadMesh', 'Amber', position=v3(g(T_IN) - .05, g(STAIR_TOP - .2), 0))
sub('BoxMesh', 'StairEdgeMesh', size=v3(.08, g(1.4), g(.06)))
for k, z in (('StairEdgeNorth', -.88), ('StairEdgeSouth', .88)):
    mesh(k, 'Level', 'StairEdgeMesh', 'Amber', position=v3(g(T_IN) - .05, g(STAIR_TOP - .9), g(z)))

# --- Basin underside and the Sanctuary (goal) ---------------------------------------------------
UNDER_X = (T_IN + R, 8.6)
umid = (UNDER_X[0] + UNDER_X[1]) / 2; ulen = UNDER_X[1] - UNDER_X[0]
comp('Underside', 'Level', kind=0, label='"Under the basin"', position=p3(umid, FLOOR[0], 0), rotation=v3(PI, 0, 0), dimensions=p3(ulen, .8, 2.4), end_sockets='false', tint=IVORY)
comp('RimSocket', 'Level/Underside', kind=2, position=p3(-ulen / 2, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(1.6)))
comp('Goal', 'Level/Underside', kind=5, position=p3(7 - umid, 0, 0), path='NodePath("..")', trigger_radius=num(g(1.2)), tint=AMBER)
mesh('Plate', 'Level/Underside/Goal', 'PlateMesh', 'Amber', position=v3(0, .02, 0))
for x in (2.6, 4.0, 5.4):
    for z in (-1.25, 1.25):
        path_lamp('Level', (x, FLOOR[0], z), (0, -1, 0))
# The Sanctuary: an amber pavilion standing on the underside (hanging, in world terms), its
# spire dropping far below the basin: the goal seen from the start.
for i, (x, z) in enumerate(((4.6, -1.5), (4.6, 1.5), (8.4, -1.5), (8.4, 1.5))):
    geometry('SanctuaryColumn%d' % i, 'Level', (x - .15, -10, z - .15), (x + .15, FLOOR[0] - .02, z + .15), AMBER)
geometry('SanctuaryRoof', 'Level', (4.2, -10.3, -1.9), (8.8, -10, 1.9), AMBER)
geometry('SanctuaryBack', 'Level', (8.7, -10, -1.6), (8.85, FLOOR[0] - .02, 1.6), AMBER)
sub('CylinderMesh', 'SpireMesh', top_radius=num(g(.9)), bottom_radius=num(g(.06)), height=num(g(16)), radial_segments=12)
mesh('Spire', 'Level', 'SpireMesh', 'Amber', position=p3(6.5, -10.3 - 8, 0))
node('SanctuaryLight', 'Level', 'OmniLight3D', position=p3(6.5, -8, 0), light_color=hexcol('f2a541'), light_energy=2.5, omni_range=num(g(6)))

# --- North gallery (fixed): top and underside, wrapping round its east end ----------------------
NG_Z = (-7.9, -6.6); NG_X = (-4, 4)
ngz = (NG_Z[0] + NG_Z[1]) / 2; ngw = NG_Z[1] - NG_Z[0]
comp('NorthGallery', 'Level', kind=0, label='"North gallery"', position=p3(0, 0, ngz), dimensions=p3(NG_X[1] - NG_X[0], .8, ngw), end_sockets='false', tint=IVORY)
comp('ArmSocket', 'Level/NorthGallery', kind=2, position=p3(0, 0, ngw / 2), path='NodePath("..")', travel_direction=v3(0, 0, 1), width=num(g(.8)))
comp('WrapSocket', 'Level/NorthGallery', kind=2, position=p3(NG_X[1], 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=num(g(ngw)))
comp('NorthWrap', 'Level', kind=1, label='"North wrap"', position=p3(NG_X[1], 0, ngz), rotation=v3(0, -PI / 2, 0), radius=num(g(.8)), dimensions=p3(2, .26, ngw), tint=IVORY)
# Underneath: flipped about X, so its local z is world -z.
comp('NorthUnder', 'Level', kind=0, label='"Under the north gallery"', position=p3(0, -1.6, ngz), rotation=v3(PI, 0, 0), dimensions=p3(NG_X[1] - NG_X[0], .8, ngw), end_sockets='false', tint=IVORY)
comp('ArmSocket', 'Level/NorthUnder', kind=2, position=p3(0, 0, -ngw / 2), path='NodePath("..")', travel_direction=v3(0, 0, -1), width=num(g(.8)))
comp('WrapSocket', 'Level/NorthUnder', kind=2, position=p3(NG_X[1], 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=num(g(ngw)))
geometry('NorthBracket', 'Level', (NG_X[0], -1.6, -B_IN), (NG_X[1], 0, NG_Z[0]), SHELL)
for x in (-3, -1, 1, 3):
    path_lamp('Level', (x, 0, NG_Z[0] + .05), (0, 1, 0))
    path_lamp('Level', (x, -1.6, NG_Z[0] + .05), (0, -1, 0))
for x in range(-4, 5):
    vine('Level', (x + .4, -1.6, -8.05), g(1.2 + (x * 3 % 5) * .7))
for x in (-2.5, 2.5):
    pendant('Level', (x, -1.6, -8.05), g(6))
particles('NorthDrips', 'Level', (0, -1.65, ngz), (3.5, 0, .5), 20, 3, 9.8, 'DripDot')

# --- Crown and Weir Arm (turn about Y, carry the player) ------------------------------------------
# Built with the Arm pointing west (angle 0); the keeper's gate is on the Crown's east inner edge,
# opposite the Arm. States: 0 west, 1 south, 2 east, 3 north (start).
CROWN, ARM_END, TONGUE = 3.2, 6.6, .4
comp('Crown', 'Level', kind=3, label='"The weir arm"', axis=v3(0, 1, 0), initial_state=3, duration=2.2, tint=TEAL)
comp('CrownDeck', 'Level/Crown', kind=0, label='"Crown and arm"', dimensions=p3(2 * ARM_END, .8, 2 * CROWN), end_sockets='false', tint=TEAL,
     regions='Array[Rect2]([%s])' % ', '.join([
         rect(-CROWN, -CROWN, 2 * CROWN, CROWN - T_IN), rect(-CROWN, T_IN, 2 * CROWN, CROWN - T_IN),
         rect(-CROWN, -T_IN, CROWN - T_IN, 2 * T_IN), rect(T_IN + R, -T_IN, CROWN - T_IN - R, 2 * T_IN),
         rect(-(ARM_END - TONGUE), -.8, ARM_END - TONGUE - CROWN, 1.6), rect(-ARM_END, -TONGUE, TONGUE, 2 * TONGUE)]))
comp('ArmTip', 'Level/Crown/CrownDeck', kind=2, position=p3(-ARM_END, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(.8)))
comp('KeepersGate', 'Level/Crown/CrownDeck', kind=2, position=p3(T_IN + R, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(1.6)))
# The gate curls over the lip and down the Crown's inner face to the throat stair's head.
comp('GateCurl', 'Level/Crown', kind=1, label='"Keeper\'s gate"', position=p3(T_IN + R, 0, 0), rotation=v3(0, PI / 2, 0),
     radius=num(g(R)), arc_degrees='"90"', tail=num(g(-STAIR_TOP - R)), dimensions=p3(2, .26, 1.6), tint=TEAL)
amid = -(CROWN + ARM_END) / 2; alen = ARM_END - CROWN
comp('ArmUnder', 'Level/Crown', kind=0, label='"Under the arm"', position=p3(amid, -1.6, 0), rotation=v3(PI, 0, 0), dimensions=p3(alen, .8, 1.6), end_sockets='false', tint=TEAL,
     regions='Array[Rect2]([%s, %s])' % (rect(-alen / 2 + TONGUE, -.8, alen - TONGUE, 1.6), rect(-alen / 2, -TONGUE, TONGUE, 2 * TONGUE)))
comp('ArmTip', 'Level/Crown/ArmUnder', kind=2, position=p3(-alen / 2, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(.8)))
# The Crown's lower body. Its inner edges drop straight into the throat (you look down it from any
# side); only the keeper's gate is marked, by tall amber-capped posts and the curl between them.
geometry('CrownLowerNorth', 'Level/Crown', (-CROWN, -1.6, -CROWN), (CROWN, -.8, -T_IN), TEAL)
geometry('CrownLowerSouth', 'Level/Crown', (-CROWN, -1.6, T_IN), (CROWN, -.8, CROWN), TEAL)
geometry('CrownLowerWest', 'Level/Crown', (-CROWN, -1.6, -T_IN), (-T_IN, -.8, T_IN), TEAL)
geometry('CrownLowerEast', 'Level/Crown', (T_IN + R, -1.6, -T_IN), (CROWN, -.8, T_IN), TEAL)
geometry('GateBack', 'Level/Crown', (T_IN + .27, -1.6, -.8), (T_IN + R, -.5, .8), TEAL)
for k, z0, z1 in (('GatePostNorth', -T_IN, -.9), ('GatePostSouth', .9, T_IN)):
    geometry(k, 'Level/Crown', (T_IN, -1.6, z0), (T_IN + R, .45, z1), TEAL)
sub('BoxMesh', 'GateMark', size=v3(g(R), .12, g(.3)))
for k, z in (('GateMarkNorth', -1.05), ('GateMarkSouth', 1.05)):
    mesh(k, 'Level/Crown', 'GateMark', 'Amber', position=v3(g(T_IN + R / 2), g(.45) + .06, g(z)))
# The gantry: rails above and below, depth marks, gauge rods into the water, a teal accent line.
sub('BoxMesh', 'ArmRail', size=v3(g(alen - TONGUE), .06, .06))
for k, y, z in (('RailTopN', 1.0, -.8), ('RailTopS', 1.0, .8), ('RailUnderN', -g(1.6) - 1.0, -.8), ('RailUnderS', -g(1.6) - 1.0, .8)):
    mesh(k, 'Level/Crown', 'ArmRail', 'Rail', position=v3(g(amid + TONGUE / 2), y, g(z) - .03 * (1 if z > 0 else -1)))
sub('BoxMesh', 'DepthMark', size=v3(.12, g(.5), .08))
for i in range(6):
    for z in (-.82, .82):
        mesh('DepthMark%d%s' % (i, 'N' if z < 0 else 'S'), 'Level/Crown', 'DepthMark', 'TealGlow', position=v3(g(-CROWN - .4 - i * .5), g(-.8), g(z) + .05 * (1 if z > 0 else -1)))
sub('CylinderMesh', 'GaugeRod', top_radius=.12, bottom_radius=.12, height=num(g(2.2)), radial_segments=6)
for k, x, z in (('GaugeNorth', -5.6, -.95), ('GaugeSouth', -4.4, .95)):
    mesh(k, 'Level/Crown', 'GaugeRod', 'Rail', position=p3(x, -2.5, z))
for x in (-5.6, -4.0):
    for z in (-.85, .85):
        path_lamp('Level/Crown', (x, 0, z), (0, 1, 0))
        path_lamp('Level/Crown', (x, -1.6, z), (0, -1, 0))
particles('ArmDrips', 'Level/Crown', (amid, -1.65, 0), (1.5, 0, .6), 30, 3, 9.8, 'DripDot')

# --- Reactive water (state-bound art, presentation only) ----------------------------------------
# Drum on edge (gate open): water pours through the gate into the basin, the channel rushes.
state_art('GateOpen', 'Level', '../Drum', (1, 3))
water_quad('GateSheet', 'Level/GateOpen', (.8, 4.6), (-B_IN + .03, -1.2, -2.0), (1, 0, 0), 'Rush')
water_quad('ChannelRush', 'Level/GateOpen', (20, 1.4), (-21.8, INTAKE_Y - .82, -2.0), (0, 1, 0), 'Rush')
particles('GateSpray', 'Level/GateOpen', (-7.6, -3.4, -2.0), (.6, .2, .6), 30, 2, 4, 'MistDot', (1, 2))
# Drum closed: the channel pools against the gate.
state_art('GateClosed', 'Level', '../Drum', (0, 2))
sub('PlaneMesh', 'PoolMesh', size='Vector2(%g, %g)' % (g(3), g(1.6)))
mesh('Pool', 'Level/GateClosed', 'PoolMesh', 'StillWater', position=p3(-13.3, INTAKE_Y - .82, -2.0))
# The keeper's gate over the stair (Arm west): an overflow runs down beside the stair.
state_art('GateAligned', 'Level', '../Crown', (0,))
for k, z in (('StairOverflowNorth', -1.0), ('StairOverflowSouth', 1.0)):
    water_quad(k, 'Level/GateAligned', (.25, 4.4), (T_IN - .01, -3.8, z), (-1, 0, 0), 'Sheet')

# --- Far world: upright towers with lit tops (world-down cues at the horizon) -------------------
sub('BoxMesh', 'FarTower', size=v3(36, 520, 36))
sub('BoxMesh', 'FarTowerTop', size=v3(40, 10, 40))
for i, (x, z, h) in enumerate(((760, -380, 60), (920, 240, 120), (-120, -980, 20), (420, -840, 90), (1080, -60, -30))):
    mesh('FarTower%d' % i, 'Level', 'FarTower', 'TowerMat', shadow=True, position=v3(x, h - 260, z))
    mesh('FarTowerTop%d' % i, 'Level', 'FarTowerTop', 'Lantern', position=v3(x, h + 5, z))

ext = ('[ext_resource type="Script" path="res://runtime/monument.gd" id="1"]\n'
       '[ext_resource type="Script" path="res://authoring/level.gd" id="2"]\n'
       '[ext_resource type="Script" path="res://authoring/component.gd" id="3"]\n'
       '[ext_resource type="Shader" path="res://world/water.gdshader" id="4"]\n'
       '[ext_resource type="Script" path="res://authoring/state_art.gd" id="5"]\n')
out = '[gd_scene load_steps=%d format=3]\n\n%s\n%s\n%s' % (5 + len(res) + 1, ext, '\n'.join(res), '\n'.join(nodes))
target = pathlib.Path(__file__).resolve().parents[1] / 'monuments' / 'the_spillway.tscn'
target.write_text(out, encoding='utf-8', newline='\n')
print('wrote', target, 'nodes', len(nodes), 'resources', len(res))
