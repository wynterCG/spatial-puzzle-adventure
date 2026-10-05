"""Generates monuments/the_threshold.tscn: The Threshold, the second complete monument
(docs/designs/2026-10-01-the-threshold.md). The scene is data; edit it here, not by hand.
Run from anywhere: python tools/gen_threshold.py

A closed core stands inside a turning sleeve. The sleeve's ledge docks with the entry in state 0;
its low window lines up with the core's low slit in state 1, and its high opening with the
core's high slit in state 3. Inside the core a slab is walked underneath, then on top after a
curl round its west end. Directions: west is -x, south is +z; r is the radius from the axis.
Everything below is at x1 and built at SCALE.
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
def mesh(name, parent, mesh_id, material, **props):
    node(name, parent, 'MeshInstance3D', mesh='SubResource("%s")' % mesh_id, material_override='SubResource("%s")' % material, cast_shadow=0, **props)

# Colour language: pale stone turns (the sleeve, with a cyan accent: "this moves"); dark stone is
# fixed (the core); warm marks the sleeve's openings, cool the core's slits and lit interior.
DARK = col(.23, .23, .26); STONE = col(.17, .17, .2); SLEEVE = col(.5, .48, .45); CORE = col(.11, .1, .13)
ACCENT = col(.55, .9, 1)
sub('StandardMaterial3D', 'GoalLight', albedo_color=col(1, .93, .85), emission_enabled='true', emission=col(1, .91, .82), emission_energy_multiplier=2.5)
sub('StandardMaterial3D', 'Lantern', albedo_color=col(1, .72, .42), emission_enabled='true', emission=col(1, .66, .34), emission_energy_multiplier=2.2)
# Rims stay saturated (a strong emission blooms to white and the warm/cool pairing is lost).
sub('StandardMaterial3D', 'Warm', albedo_color=col(1, .55, .2), emission_enabled='true', emission=col(1, .5, .15), emission_energy_multiplier=1.1)
sub('StandardMaterial3D', 'Cool', albedo_color=col(.3, .62, 1), emission_enabled='true', emission=col(.25, .58, 1), emission_energy_multiplier=1.1)
sub('StandardMaterial3D', 'Accent', albedo_color=col(.55, .9, 1), emission_enabled='true', emission=col(.5, .88, 1), emission_energy_multiplier=1.4)
sub('StandardMaterial3D', 'SignLight', albedo_color=col(.95, .95, 1), emission_enabled='true', emission=col(.9, .93, 1), emission_energy_multiplier=1.6)
sub('StandardMaterial3D', 'CrownStone', albedo_color=col(.11, .1, .13), roughness=.8)
sub('BoxMesh', 'BeamMesh', size=v3(.64, 160, .64))
sub('BoxMesh', 'PlateMesh', size=v3(g(1.2), .04, g(1.2)))
sub('BoxMesh', 'LanternMesh', size=p3(.6, .6, .6))

# --- Doorways --------------------------------------------------------------------------------
DOOR_W, DOOR_H, REACH = .8, 1.4, 2.0
SIGN = DOOR_W / 1.6
sub('CylinderMesh', 'SignDisc', top_radius=num(g(.45 * SIGN)), bottom_radius=num(g(.45 * SIGN)), height=num(g(.08)), radial_segments=32)
sub('BoxMesh', 'SignDiamond', size=p3(.08, .6 * SIGN, .6 * SIGN))
sub('BoxMesh', 'SignBar', size=p3(.08, .15 * SIGN, .8 * SIGN))
sub('TorusMesh', 'SignRing', inner_radius=num(g(.3 * SIGN)), outer_radius=num(g(.45 * SIGN)), rings=32, ring_segments=8)

def doorway(name, label, parent, at, out, sign, up=(0, 1, 0)):
    """A doorway at a path edge (in the path's frame) with a sign above its lintel, flat in the
    doorway's plane: disc, diamond, bar, bars or ring (blockout stand-ins for identity)."""
    comp(name, parent, kind=9, label='"%s"' % label, position=p3(*at), path='NodePath("..")',
         travel_direction=v3(*out), ground_normal=v3(*up), width=num(g(DOOR_W)), aperture_height=num(g(DOOR_H)),
         trigger_radius=num(g(REACH)), link_group='"threshold"', tint=ACCENT)
    holder = '%s/%s' % (parent, name)
    # The mount's YZ plane is the doorway's plane.
    node('SignMount', holder, position=v3(0, g(DOOR_H + .75 * SIGN), 0), rotation=v3(0, 0 if abs(out[0]) > .5 else PI / 2, 0))
    mount = holder + '/SignMount'
    if sign == 'disc': mesh('Sign', mount, 'SignDisc', 'SignLight', rotation=v3(0, 0, PI / 2))
    elif sign == 'diamond': mesh('Sign', mount, 'SignDiamond', 'SignLight', rotation=v3(PI / 4, 0, 0))
    elif sign == 'bar': mesh('Sign', mount, 'SignBar', 'SignLight')
    elif sign == 'bars':
        for k, dy in (('SignUpper', .18 * SIGN), ('SignLower', -.18 * SIGN)):
            mesh(k, mount, 'SignBar', 'SignLight', position=v3(0, g(dy), 0))
    else: mesh('Sign', mount, 'SignRing', 'SignLight', rotation=v3(0, 0, PI / 2))

# --- Rings of box segments (line of sight and the eye probe see boxes, not CSG) ---------------
SEGMENTS = 16
def ring(parent, prefix, r_in, r_out, y0, y1, tint, openings):
    """A ring wall of SEGMENTS boxes; segment i is centred at angle i * 360/SEGMENTS (0 = east,
    90 = south). `openings` maps a segment index to (width, y_low, y_high): that segment is split
    into boxes around the gap."""
    r = (r_in + r_out) / 2
    depth = r_out - r_in
    length = 2 * r_out * math.tan(PI / SEGMENTS)  # closes the outer face; the inner corners overlap
    for i in range(SEGMENTS):
        t = i * 2 * PI / SEGMENTS
        radial = (math.cos(t), math.sin(t))
        tangent = (-math.sin(t), math.cos(t))
        def box(name, y_low, y_high, offset, size):
            comp('%s%02d%s' % (prefix, i, name), parent, kind=8, position=p3(r * radial[0] + offset * tangent[0], (y_low + y_high) / 2, r * radial[1] + offset * tangent[1]),
                 rotation=v3(0, -t, 0), dimensions=p3(depth, y_high - y_low, size), tint=tint)
        if i not in openings:
            box('', y0, y1, 0, length)
            continue
        w, low, high = openings[i]
        side = (length - w) / 2
        box('Below', y0, low, 0, length)
        box('Above', high, y1, 0, length)
        box('Left', low, high, -(w + side) / 2, side)
        box('Right', low, high, (w + side) / 2, side)

def rim(name, parent, angle_degrees, radius, width, y_low, y_high, material):
    """A light outlining an opening on a ring's outer face (a few centimetres proud of it)."""
    t = math.radians(angle_degrees)
    holder = '%s/%s' % (parent, name)
    node(name, parent, position=v3((g(radius) + .05) * math.cos(t), 0, (g(radius) + .05) * math.sin(t)), rotation=v3(0, -t, 0))
    sub('BoxMesh', name + 'Across', size=v3(.08, .14, g(width) + .28))
    sub('BoxMesh', name + 'Up', size=v3(.08, g(y_high - y_low), .14))
    for k, y in (('Top', y_high), ('Bottom', y_low)):
        mesh(k, holder, name + 'Across', material, position=v3(0, g(y), 0))
    for k, z in (('Left', -width / 2), ('Right', width / 2)):
        mesh(k, holder, name + 'Up', material, position=v3(0, g((y_low + y_high) / 2), g(z)))

QUESTION = "From where can you see into the tower?"
EXPLANATION = ("The tower has no door, and the shell around it turns. Ride the ledge one turn: the sleeve's low window lines up with "
               "the core's low slit, and from the ledge door you see a doorway hanging inside. Link to it and cross. Inside, curl over the "
               "slab's edge onto its top, then turn the sleeve twice: the high opening lines up with the high slit and shows the balcony door.")
HINTS = ["The outer shell turns; the tower inside it does not. What can you see through its openings, and from where?",
         "Stand at the ledge door and ride the sleeve one turn: the window and the low slit line up.",
         "Link the ledge door to the door inside and cross. Curl onto the slab top, turn the sleeve twice, link the high door to the balcony door and cross."]

node('Puzzle', None, script='1')
node('Level', '.', script='2',
     level_id='"the_threshold"', revision=1, title='"The threshold"',
     question='"%s"' % QUESTION, explanation='"%s"' % EXPLANATION,
     overview_focus=p3(-2, 3, 0), overview_size=num(g(38)),
     overview_azimuth_degrees=-50, overview_elevation_degrees=38,
     sweep_tolerance=num(.04 * SCALE), discovery_range=num(g(40)),
     hints='PackedStringArray(%s)' % ', '.join('"%s"' % h for h in HINTS))

# --- Entry (west, fixed) ----------------------------------------------------------------------
# A broad deck with a narrow tongue at its east end: the tongue docks with the ledge's tongue, and
# their corners stay inside the sweep tolerance when the sleeve turns.
TONGUE = 1.6
comp('Entry', 'Level', kind=0, label='"Entry"', position=p3(-13, 0, 0), dimensions=p3(8, .8, 4), end_sockets='false', tint=DARK,
     regions='Array[Rect2]([%s, %s])' % (rect(-4, -2, 7.4, 4), rect(3.4, -TONGUE / 2, .6, TONGUE)))
comp('LedgeSocket', 'Level/Entry', kind=2, position=p3(4, 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=num(g(TONGUE)))
comp('PlayerStart', 'Level/Entry', kind=4, position=p3(1, 0, 0), path='NodePath("..")')
doorway('Gate', 'Gate', 'Level/Entry', (-4, 0, 0), (-1, 0, 0), 'disc')
comp('EntryPier', 'Level', kind=8, position=p3(-14, -.8 - 25, 0), dimensions=p3(1.2, 50, 1.2), tint=STONE)
comp('LanternPost', 'Level', kind=8, position=p3(-13.5, 1.6, 2.6), dimensions=p3(.3, 3.2, .3), tint=STONE)
mesh('Lantern', 'Level/LanternPost', 'LanternMesh', 'Lantern', position=p3(0, 1.9, 0))

# --- Core (fixed, closed) --------------------------------------------------------------------
CORE_IN, CORE_OUT, CORE_Y = 3.4, 4.0, (-6, 12)
LOW_SLIT = (.9, 1.2, 3.0)    # south
HIGH_SLIT = (.9, 6.0, 7.6)   # east
node('Core', 'Level')
ring('Level/Core', 'CoreWall', CORE_IN, CORE_OUT, CORE_Y[0], CORE_Y[1], CORE, {4: LOW_SLIT, 0: HIGH_SLIT})
comp('CoreFloor', 'Level/Core', kind=8, position=p3(0, CORE_Y[0] + .2, 0), dimensions=p3(4.8, .4, 4.8), tint=CORE)
comp('CoreRoof', 'Level/Core', kind=8, position=p3(0, CORE_Y[1] - .2, 0), dimensions=p3(4.8, .4, 4.8), tint=CORE)
sub('CylinderMesh', 'CrownMesh', top_radius=num(g(4.3)), bottom_radius=num(g(4.3)), height=num(g(.8)), radial_segments=48)
sub('CylinderMesh', 'BaseMesh', top_radius=num(g(3.9)), bottom_radius=num(g(3.2)), height=num(g(40)), radial_segments=48)
node('Crown', 'Level/Core', 'MeshInstance3D', position=p3(0, CORE_Y[1] + .4, 0), mesh='SubResource("CrownMesh")', material_override='SubResource("CrownStone")')
node('Base', 'Level/Core', 'MeshInstance3D', position=p3(0, CORE_Y[0] - 20, 0), mesh='SubResource("BaseMesh")', material_override='SubResource("CrownStone")')
rim('LowSlitRim', 'Level/Core', 90, CORE_OUT, LOW_SLIT[0], LOW_SLIT[1], LOW_SLIT[2], 'Cool')
rim('HighSlitRim', 'Level/Core', 0, CORE_OUT, HIGH_SLIT[0], HIGH_SLIT[1], HIGH_SLIT[2], 'Cool')
# The lit interior: a cool lamp band on the inner north wall, behind the under door as seen
# through the low slit, and soft cool light.
sub('BoxMesh', 'LampBand', size=v3(g(2.4), g(2.8), .1))
mesh('LampBand', 'Level/Core', 'LampBand', 'Cool', position=v3(0, g(2.4), -g(CORE_IN) + .3))
for k, y in (('InteriorLightLow', 2.4), ('InteriorLightHigh', 8)):
    node(k, 'Level/Core', 'OmniLight3D', position=p3(0, y, 0), light_color=col(.7, .85, 1), light_energy=1.2, omni_range=num(g(4.2)))

# The slab: top y 6, underside y 4, a 180 degree curl of radius 1 at its west end (x -1.4).
SLAB_X = (-1.4, 2.4); SLAB_TOP, SLAB_UNDER = 6, 4
mid = (SLAB_X[0] + SLAB_X[1]) / 2; length = SLAB_X[1] - SLAB_X[0]
comp('SlabTop', 'Level/Core', kind=0, label='"Slab top"', position=p3(mid, SLAB_TOP, 0), dimensions=p3(length, .8, 1.6), end_sockets='false', tint=DARK)
comp('CurlSocket', 'Level/Core/SlabTop', kind=2, position=p3(-length / 2, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(1.6)))
doorway('HighDoor', 'High door', 'Level/Core/SlabTop', (length / 2, 0, 0), (1, 0, 0), 'bars')
comp('SlabCurl', 'Level/Core', kind=1, label='"Slab curl"', position=p3(SLAB_X[0], SLAB_TOP, 0), rotation=v3(0, PI / 2, 0), radius=num(g(1)), dimensions=p3(2, .26, 1.6), tint=DARK)
# Underneath: flipped about X, so its local z is world -z. The under door stands on its south edge.
comp('SlabUnder', 'Level/Core', kind=0, label='"Slab underside"', position=p3(mid, SLAB_UNDER, 0), rotation=v3(PI, 0, 0), dimensions=p3(length, .8, 1.6), end_sockets='false', tint=DARK)
comp('CurlSocket', 'Level/Core/SlabUnder', kind=2, position=p3(-length / 2, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(1.6)))
doorway('UnderDoor', 'Under door', 'Level/Core/SlabUnder', (-mid, 0, -.8), (0, 0, -1), 'bar')
# Cool guide lines (as in The Ring's tower): from the under door along the underside, visibly over
# the curl, and along the top to the high door, so the route reads on arrival upside down.
TRIM = .035
sub('BoxMesh', 'GuideMesh', size=v3(g(length), .02, g(.06)))
mesh('GuideTop', 'Level/Core', 'GuideMesh', 'Cool', position=v3(g(mid), g(SLAB_TOP) + TRIM, 0))
mesh('GuideUnder', 'Level/Core', 'GuideMesh', 'Cool', position=v3(g(mid), g(SLAB_UNDER) - TRIM, 0))
node('GuideCurl', 'Level/Core', 'CSGTorus3D', position=p3(SLAB_X[0], (SLAB_TOP + SLAB_UNDER) / 2, 0), rotation=v3(PI / 2, 0, 0),
     inner_radius=num(g(1.01)), outer_radius=num(g(1.06)), sides=48, ring_sides=6, material='SubResource("Cool")')
node('GuideCurlCut', 'Level/Core/GuideCurl', 'CSGBox3D', position=p3(1, 0, 0), operation=2, size=p3(2, 3, 3))
comp('SlabCore', 'Level/Core', kind=8, position=p3(mid, 5, 0), dimensions=p3(length - .1, .5, 1.5), tint=CORE)
comp('SlabBeam', 'Level/Core', kind=8, position=p3((SLAB_X[1] + CORE_IN + .2) / 2, 5, 0), dimensions=p3(CORE_IN + .2 - SLAB_X[1], .4, .6), tint=CORE)

# --- Sleeve (turns about Y, carries the player) -----------------------------------------------
SLEEVE_IN, SLEEVE_OUT, SLEEVE_Y = 6.0, 6.6, (-2, 9)
WINDOW = (1.2, 0, 2.2)       # local west: with the ledge
HIGH_OPENING = (1.4, 5.8, 8) # local north: east in state 3
comp('Sleeve', 'Level', kind=3, label='"The sleeve"', axis=v3(0, 1, 0), initial_state=0, duration=1.8, tint=ACCENT)
ring('Level/Sleeve', 'SleeveWall', SLEEVE_IN, SLEEVE_OUT, SLEEVE_Y[0], SLEEVE_Y[1], SLEEVE, {8: WINDOW, 12: HIGH_OPENING})
rim('WindowRim', 'Level/Sleeve', 180, SLEEVE_OUT, WINDOW[0], WINDOW[1], WINDOW[2], 'Warm')
rim('HighOpeningRim', 'Level/Sleeve', 270, SLEEVE_OUT, HIGH_OPENING[0], HIGH_OPENING[1], HIGH_OPENING[2], 'Warm')
sub('TorusMesh', 'BandMesh', inner_radius=num(g(SLEEVE_OUT) - .1), outer_radius=num(g(SLEEVE_OUT) + .25), rings=96, ring_segments=6)
for k, y in (('BandTop', SLEEVE_Y[1] - .3), ('BandBottom', SLEEVE_Y[0] + .3)):
    mesh(k, 'Level/Sleeve', 'BandMesh', 'Accent', position=p3(0, y, 0))
# The ledge (local west, r 6.8 -> 9.0, top y 0): a broad deck with a docking tongue at its outer
# edge. The ledge door stands at its inner edge, right in front of the window.
LEDGE_R = (6.8, 9.0); LEDGE_TONGUE = .4
ledge_mid = (LEDGE_R[0] + LEDGE_R[1]) / 2; ledge_depth = LEDGE_R[1] - LEDGE_R[0]
comp('Ledge', 'Level/Sleeve', kind=0, label='"Ledge"', position=p3(-ledge_mid, 0, 0), dimensions=p3(ledge_depth, .8, 4), end_sockets='false', tint=DARK,
     regions='Array[Rect2]([%s, %s])' % (rect(-ledge_depth / 2 + LEDGE_TONGUE, -2, ledge_depth - LEDGE_TONGUE, 4), rect(-ledge_depth / 2, -TONGUE / 2, LEDGE_TONGUE, TONGUE)))
comp('EntrySocket', 'Level/Sleeve/Ledge', kind=2, position=p3(-ledge_depth / 2, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=num(g(TONGUE)))
doorway('LedgeDoor', 'Ledge door', 'Level/Sleeve/Ledge', (ledge_depth / 2, 0, 0), (1, 0, 0), 'diamond')
comp('LedgeBracket', 'Level/Sleeve', kind=8, position=p3(-(SLEEVE_IN + LEDGE_R[0] + .4) / 2, -1.4, 0), dimensions=p3(LEDGE_R[0] + .4 - SLEEVE_IN, 1.2, 3), tint=SLEEVE)
# Accent edges round the ledge: it moves.
sub('BoxMesh', 'LedgeEdgeLong', size=v3(g(ledge_depth - LEDGE_TONGUE), .06, .1))
for k, z in (('LedgeEdgeNorth', -2), ('LedgeEdgeSouth', 2)):
    mesh(k, 'Level/Sleeve', 'LedgeEdgeLong', 'Accent', position=v3(-g(ledge_mid - LEDGE_TONGUE / 2), .03, g(z) - .05 * (z / abs(z))))

# --- Balcony (fixed, outside the sleeve, high, east) -------------------------------------------
# Its door stands back from the deck's west end, behind a stone sill: the ledge passes right below
# in state 2, and the sill and a soffit hide the door from there. Side walls hide it from the sides.
# The only sight line to the balcony door runs through the core's high slit and the sleeve's high
# opening. Everything here stays outside the sleeve's sweep (r <= 6.73).
BAL_X = (6.9, 10.1); SILL = .5; BAL_Y = 6
walk_x = (BAL_X[0] + SILL, BAL_X[1])
bal_mid = (walk_x[0] + walk_x[1]) / 2; bal_len = walk_x[1] - walk_x[0]
comp('Balcony', 'Level', kind=0, label='"Balcony"', position=p3(bal_mid, BAL_Y, 0), dimensions=p3(bal_len, .8, 4), end_sockets='false', tint=DARK)
doorway('BalconyDoor', 'Balcony door', 'Level/Balcony', (-bal_len / 2, 0, 0), (-1, 0, 0), 'ring')
comp('Goal', 'Level/Balcony', kind=5, position=p3(.5, 0, 0), path='NodePath("..")', trigger_radius=num(g(1.2)), tint=ACCENT)
mesh('Plate', 'Level/Balcony/Goal', 'PlateMesh', 'GoalLight', position=v3(0, .02, 0))
# The beam starts well above head height and rises far above the tower: seen from the start.
mesh('LightShaft', 'Level/Balcony/Goal', 'BeamMesh', 'GoalLight', position=v3(0, g(2.5) + 80, 0))
comp('BalconySill', 'Level', kind=8, position=p3(BAL_X[0] + SILL / 2, BAL_Y - .4, 0), dimensions=p3(SILL, .8, 4), tint=STONE)
# A doorway's own deck never hides it, so a stone soffit under the deck does.
comp('BalconySoffit', 'Level', kind=8, position=p3((BAL_X[0] + BAL_X[1]) / 2, BAL_Y - 1.1, 0), dimensions=p3(BAL_X[1] - BAL_X[0], .6, 4.6), tint=STONE)
for k, z in (('BalconyWallNorth', -2.15), ('BalconyWallSouth', 2.15)):
    comp(k, 'Level', kind=8, position=p3((BAL_X[0] + BAL_X[1]) / 2, BAL_Y + 1.1, z), dimensions=p3(BAL_X[1] - BAL_X[0], 2.2, .3), tint=STONE)
comp('BalconyPier', 'Level', kind=8, position=p3(10, (BAL_Y - .8 - 50) / 2, 0), dimensions=p3(1, BAL_Y - .8 + 50, 1.2), tint=STONE)

ext = ('[ext_resource type="Script" path="res://runtime/monument.gd" id="1"]\n'
       '[ext_resource type="Script" path="res://authoring/level.gd" id="2"]\n'
       '[ext_resource type="Script" path="res://authoring/component.gd" id="3"]\n')
out = '[gd_scene load_steps=%d format=3]\n\n%s\n%s\n%s' % (3 + len(res) + 1, ext, '\n'.join(res), '\n'.join(nodes))
target = pathlib.Path(__file__).resolve().parents[1] / 'monuments' / 'the_threshold.tscn'
target.write_text(out, encoding='utf-8', newline='\n')
print('wrote', target, 'nodes', len(nodes))
