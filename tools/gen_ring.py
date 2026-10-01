"""Generates monuments/the_ring.tscn (The Ring v3). The scene is data; edit it here, not by hand.
Run from anywhere: python tools/gen_ring.py"""
import math, sys
PI = math.pi
res = []
def sub(t, i, **props):
    body = '\n'.join('%s = %s' % (k, v) for k, v in props.items())
    res.append('[sub_resource type="%s" id="%s"]\n%s\n' % (t, i, body))
def col(r, g, b, a=1): return 'Color(%g, %g, %g, %g)' % (r, g, b, a)
def v3(x, y, z): return 'Vector3(%g, %g, %g)' % (x, y, z)

# Monument scale (docs/designs/2026-10-01-monumental-scale.md). Everything authored about the
# monument scales; the player (1.55 m eye) does not, and neither do surface trims that sit a few
# centimetres above a deck. tests/test_helpers.gd RING_SCALE matches.
SCALE = 4
def s(x): return '%g' % (x * SCALE)
def p3(x, y, z): return v3(x * SCALE, y * SCALE, z * SCALE)
def rect(x, y, w, h): return 'Rect2(%g, %g, %g, %g)' % (x * SCALE, y * SCALE, w * SCALE, h * SCALE)
TRIM = .035 # height of a light line above its deck, unscaled

# Composition arguments: focus "x,y,z", size, azimuth, elevation
args = sys.argv[1:] + [None] * 4
focus = tuple(map(float, args[0].split(','))) if args[0] else (1, 0.5, 0)
size = args[1] or '36'
azimuth = args[2] or '-45'
elevation = args[3] or 43.31

sub('StandardMaterial3D', 'RingMaterial', albedo_color=col(.13, .12, .15), metallic=.3, roughness=.6)
sub('StandardMaterial3D', 'Magenta', albedo_color=col(.86, .36, .62), emission_enabled='true', emission=col(.86, .36, .62), emission_energy_multiplier=1.6)
sub('StandardMaterial3D', 'GoalLight', albedo_color=col(1, .93, .85), emission_enabled='true', emission=col(1, .91, .82), emission_energy_multiplier=2.5)
# Colour language: an accent light means 'this moves' (ring magenta, inner wheel lilac);
# warm white is information and destination; static architecture stays neutral.
sub('StandardMaterial3D', 'Lilac', albedo_color=col(.78, .72, .95), emission_enabled='true', emission=col(.74, .68, .95), emission_energy_multiplier=1.6)
sub('StandardMaterial3D', 'WarmLine', albedo_color=col(1, .9, .78), emission_enabled='true', emission=col(1, .88, .74), emission_energy_multiplier=1.3)
sub('StandardMaterial3D', 'Foliage', albedo_color=col(.2, .27, .24), roughness=.95)
sub('StandardMaterial3D', 'TowerMaterial', albedo_color=col(.16, .16, .19), roughness=.8)
sub('BoxMesh', 'BandMesh', size=p3(1.6, 1, 1.34))
sub('TorusMesh', 'InnerLineMesh', inner_radius=s(5.55), outer_radius=s(5.68), rings=128, ring_segments=6)
sub('TorusMesh', 'HubLineMesh', inner_radius=s(2.74), outer_radius=s(2.84), rings=64, ring_segments=6)
sub('TorusMesh', 'HubMesh', inner_radius=s(2.52), outer_radius=s(2.74), rings=64, ring_segments=8)
sub('BoxMesh', 'Strip', size=p3(.12, .04, 1.62))
sub('BoxMesh', 'TowerStrip', size=p3(.06, 15, .3))
sub('BoxMesh', 'BeamMesh', size=p3(.16, 40, .16))
sub('BoxMesh', 'ThresholdMesh', size=v3(.25 * SCALE, .04, 1.6 * SCALE))
sub('SphereMesh', 'CanopyMesh', radius=s(.55), height=s(.95), radial_segments=16, rings=8)
sub('BoxMesh', 'PierHeadMesh', size=p3(3.7, 2.4, 1.6))
sub('CylinderMesh', 'PierNoseMesh', top_radius=s(1.7), bottom_radius=s(1.7), height=s(1.6), radial_segments=32)
sub('BoxMesh', 'EntryMassMesh', size=p3(3.7, 1, 1.6))
sub('BoxMesh', 'EntryPierMesh', size=p3(1.2, 50, 1.2))
sub('BoxMesh', 'JambGlowMesh', size=p3(.14, 3.4, .03))
sub('BoxMesh', 'LintelGlowMesh', size=p3(.14, .03, 2.0))
sub('BoxMesh', 'GuideMesh', size=v3(1.8 * SCALE, .02, .06 * SCALE))
sub('BoxMesh', 'BalconyGuideMesh', size=v3(4 * SCALE, .02, .5 * SCALE))

nodes = []
def node(name, parent, typ='Node3D', script=None, **props):
    head = '[node name="%s" type="%s" parent="%s"]' % (name, typ, parent) if parent is not None else '[node name="%s" type="%s"]' % (name, typ)
    lines = [head]
    if script: lines.append('script = ExtResource("%s")' % script)
    lines += ['%s = %s' % (k, v) for k, v in props.items()]
    nodes.append('\n'.join(lines) + '\n')
def comp(name, parent, **props): node(name, parent, script='3', **props)
DARK = col(.23, .23, .26); STRUCT = col(.13, .12, .15); ARM = col(.3, .27, .31); STONE = col(.17, .17, .2)
FLIP = v3(PI, 0, 0)

EXPLANATION = ("The way out is underneath. Line up the inner wheel's top arm behind the ring arm and walk into the tower: "
               "its floor curls you underneath to the lower door. From inside, turn the inner wheel until its underside arm reaches you, "
               "walk out beneath it onto the underside of the ring arm you came in on, and ride the ring around to the balcony.")
HINTS = ["Look through the narrow slot in the tower when you are inside it.",
         "The tower opens on one side only. Something must line up with its upper door before you can enter.",
         "Turn the inner wheel so its top arm meets the ring arm, enter the tower, turn the inner wheel again from inside, step out underneath, and ride the ring to the balcony."]

node('Puzzle', None, script='1')
node('Level', '.', script='2',
     level_id='"the_ring"', revision=4, sweep_tolerance=.16, title='"The ring"',
     question='"What do you see from inside the tower?"',
     explanation='"%s"' % EXPLANATION,
     overview_focus=p3(*focus), overview_size=s(float(size)),
     overview_azimuth_degrees=azimuth, overview_elevation_degrees=elevation,
     hints='PackedStringArray(%s)' % ', '.join('"%s"' % h for h in HINTS))

# Entry outpost
comp('Entry', 'Level', kind=0, label='"Entry bridge"', position=p3(-10, 1, 0), dimensions=p3(4, .8, 1.6), tint=DARK)
comp('PlayerStart', 'Level/Entry', kind=4, position=p3(-1.2, 0, 0), path='NodePath("..")')
for n, z in (('EntryJambL', -1.15), ('EntryJambR', 1.15)):
    comp(n, 'Level', kind=8, position=p3(-11.75, 2.3, z), dimensions=p3(.4, 4.2, .3), tint=STONE)
comp('EntryLintel', 'Level', kind=8, position=p3(-11.75, 4.6, 0), dimensions=p3(.4, .4, 2.6), tint=STONE)

# Hollow tower: decorative CSG shell (no collision); the route inside is authored paths.
node('TowerShell', 'Level', 'CSGCylinder3D', position=p3(0, 2, 0), radius=s(2.4), height=400, sides=32, material='SubResource("TowerMaterial")')
for n, pos, size_ in (('Cavity', (0, -2, 0), (4.2, 6.8, 1.2)),
                      ('UpperDoor', (-2.3, -0.2, 0), (0.8, 3.2, 1.2)),
                      ('LowerDoor', (-2.3, -3.8, 0), (0.8, 3.2, 1.2)),
                      ):
    node(n, 'Level/TowerShell', 'CSGBox3D', position=p3(*pos), operation=2, size=p3(*size_))
# Sightline: from the lower-door eye (player eye height, unscaled) to the balcony underside light.
eye_x, eye_y = -2.4 * SCALE, -1 * SCALE - 1.55
light_x, light_y = 10 * SCALE, -SCALE - TRIM
slot_x = 2.3 * SCALE
slot_y = eye_y + (light_y - eye_y) * (slot_x - eye_x) / (light_x - eye_x)
node('EastSlot', 'Level/TowerShell', 'CSGBox3D', position=v3(slot_x, slot_y - 2 * SCALE, 0), operation=2, size=p3(0.8, 0.9, 0.42))
node('TowerLight', 'Level', 'MeshInstance3D', position=p3(1.7, 2.5, 1.7), rotation=v3(0, PI / 4, 0), mesh='SubResource("TowerStrip")', material_override='SubResource("WarmLine")')
# The curl sits west of centre: on its vertical part the player stands sideways (east), and
# the body must stay inside the cavity, clear of the inner wheel's sweep.
node('InteriorLightUpper', 'Level', 'OmniLight3D', position=p3(-1.2, 2.7, 0), light_color=col(1, .86, .74), light_energy=.8, omni_range=s(3.4))
node('InteriorLightLower', 'Level', 'OmniLight3D', position=p3(-1.2, -2.7, 0), light_color=col(1, .86, .74), light_energy=.8, omni_range=s(3.4))
comp('TowerTop', 'Level', kind=0, label='"Tower floor"', position=p3(-1.6, 1, 0), dimensions=p3(1.8, .8, .8), tint=DARK)
comp('TowerCurl', 'Level', kind=1, label='"Tower curl"', position=p3(-0.7, 1, 0), rotation=v3(0, -PI / 2, 0), radius=s(1.0), dimensions=p3(2, .26, .8), tint=DARK)
# First-person cue: a magenta guide line runs along the tower floor, visibly curls over its edge
# and continues underneath, so the route reads from the upper door (isometric never sees it).
node('GuideTop', 'Level', 'MeshInstance3D', position=v3(-1.6 * SCALE, SCALE + TRIM, 0), mesh='SubResource("GuideMesh")', material_override='SubResource("WarmLine")', cast_shadow=0)
node('GuideUnder', 'Level', 'MeshInstance3D', position=v3(-1.6 * SCALE, -SCALE - TRIM, 0), mesh='SubResource("GuideMesh")', material_override='SubResource("WarmLine")', cast_shadow=0)
node('GuideCurl', 'Level', 'CSGTorus3D', position=p3(-0.7, 0, 0), rotation=v3(PI / 2, 0, 0), inner_radius=s(1.01), outer_radius=s(1.06), sides=48, ring_sides=6, material='SubResource("WarmLine")')
node('GuideCurlCut', 'Level/GuideCurl', 'CSGBox3D', position=p3(-1, 0, 0), operation=2, size=p3(2, 3, 3))
comp('TowerUnder', 'Level', kind=0, label='"Tower underside"', position=p3(-1.6, -1, 0), rotation=FLIP, dimensions=p3(1.8, .8, .8), tint=DARK)

# Inner wheel: east arm walkable on top only, west arm underneath only.
comp('InnerWheel', 'Level', kind=3, label='"Inner wheel"', axis=v3(0, 1, 0), initial_state=0, duration=1.6, tint=col(.78, .72, .9))
node('Hub', 'Level/InnerWheel', 'MeshInstance3D', mesh='SubResource("HubMesh")', material_override='SubResource("RingMaterial")')
node('HubLine', 'Level/InnerWheel', 'MeshInstance3D', mesh='SubResource("HubLineMesh")', material_override='SubResource("Lilac")')
node('InnerTopTip', 'Level/InnerWheel', 'MeshInstance3D', position=p3(4.88, 0, 0), mesh='SubResource("Strip")', material_override='SubResource("Lilac")')
node('InnerUnderTip', 'Level/InnerWheel', 'MeshInstance3D', position=p3(-4.88, 0, 0), mesh='SubResource("Strip")', material_override='SubResource("Lilac")')
comp('InnerTop', 'Level/InnerWheel', kind=0, label='"Inner arm, top"', position=p3(3.75, 1, 0), dimensions=p3(2.5, .8, 1.6), tint=ARM, end_sockets='false',
     regions='Array[Rect2]([%s, %s])' % (rect(-1.25, -0.4, 0.5, 0.8), rect(-0.75, -0.8, 2, 1.6)))
comp('DoorSocket', 'Level/InnerWheel/InnerTop', kind=2, position=p3(-1.25, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=s(.8))
comp('RingSocket', 'Level/InnerWheel/InnerTop', kind=2, position=p3(1.25, 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=s(1.6))
comp('InnerTopCore', 'Level/InnerWheel', kind=8, position=p3(3.85, 0, 0), dimensions=p3(2.1, .4, 1.2), tint=STRUCT)
comp('InnerUnder', 'Level/InnerWheel', kind=0, label='"Inner arm, underside"', position=p3(-3.75, -1, 0), rotation=FLIP, dimensions=p3(2.5, .8, 1.6), tint=ARM, end_sockets='false',
     regions='Array[Rect2]([%s, %s])' % (rect(0.75, -0.4, 0.5, 0.8), rect(-1.25, -0.8, 2, 1.6)))
comp('DoorSocket', 'Level/InnerWheel/InnerUnder', kind=2, position=p3(1.25, 0, 0), path='NodePath("..")', travel_direction=v3(1, 0, 0), width=s(.8))
comp('RingSocket', 'Level/InnerWheel/InnerUnder', kind=2, position=p3(-1.25, 0, 0), path='NodePath("..")', travel_direction=v3(-1, 0, 0), width=s(1.6))
comp('InnerUnderCore', 'Level/InnerWheel', kind=8, position=p3(-3.85, 0, 0), dimensions=p3(2.1, .4, 1.2), tint=STRUCT)

# Ring: the band and one arm walkable on both faces.
comp('Ring', 'Level', kind=3, label='"The ring"', axis=v3(0, 1, 0), initial_state=2, duration=1.8, tint=col(.86, .36, .62))
node('RingArt', 'Level/Ring')
for i in range(32):
    t = i * 2 * PI / 32
    node('Band%02d' % i, 'Level/Ring/RingArt', 'MeshInstance3D',
         transform='Transform3D(%.6f, 0, %.6f, 0, 1, 0, %.6f, 0, %.6f, %.6f, 0, %.6f)' % (math.cos(t), math.sin(t), -math.sin(t), math.cos(t), 6.5 * SCALE * math.cos(t), -6.5 * SCALE * math.sin(t)),
         mesh='SubResource("BandMesh")', material_override='SubResource("RingMaterial")')
node('InnerLine', 'Level/Ring', 'MeshInstance3D', mesh='SubResource("InnerLineMesh")', material_override='SubResource("Magenta")')
comp('RingTop', 'Level/Ring', kind=0, label='"Ring arm, top"', position=p3(6.5, 1, 0), dimensions=p3(3, .8, 1.6), tint=ARM)
comp('RingUnder', 'Level/Ring', kind=0, label='"Ring arm, underside"', position=p3(6.5, -1, 0), rotation=FLIP, dimensions=p3(3, .8, 1.6), tint=ARM)
comp('RingCore', 'Level/Ring', kind=8, position=p3(6.6, 0, 0), dimensions=p3(2.6, .4, 1.2), tint=STRUCT)
node('TipLight', 'Level/Ring', 'MeshInstance3D', position=p3(7.85, 0, 0), mesh='SubResource("Strip")', material_override='SubResource("Magenta")')

# Exit: balcony underside, curl up to the terrace with the light.
comp('Balcony', 'Level', kind=0, label='"Balcony underside"', position=p3(10, -1, 0), rotation=FLIP, dimensions=p3(4, .8, 1.6), tint=DARK)
# The destination's warm light also runs under the balcony: seen through the tower's east slot.
node('BalconyGuide', 'Level', 'MeshInstance3D', position=v3(10 * SCALE, -SCALE - TRIM, 0), mesh='SubResource("BalconyGuideMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)
comp('FarCurve', 'Level', kind=1, label='"Terrace curve"', position=p3(12, 3, 0), rotation=v3(0, -PI / 2, 0), radius=s(2.0), dimensions=p3(2, .26, 1.6), tint=DARK)
comp('Terrace', 'Level', kind=0, label='"Terrace"', position=p3(10, 3, 0), dimensions=p3(4, .8, 1.6), tint=DARK)
# The light completes the monument from anywhere across the wide terrace, edges included
# (radius > the terrace half-width, 0.8 x SCALE).
comp('Goal', 'Level/Terrace', kind=5, position=p3(-1.4, 0, 0), path='NodePath("..")', trigger_radius=s(1.0), tint=col(.86, .36, .62))
node('LightShaft', 'Level/Terrace/Goal', 'MeshInstance3D', position=p3(-0.35, 23.8, 0), mesh='SubResource("BeamMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)
node('Threshold', 'Level/Terrace/Goal', 'MeshInstance3D', position=v3(-0.35 * SCALE, 0.02, 0), mesh='SubResource("ThresholdMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)
for n, z in (('TerraceJambL', -1.15), ('TerraceJambR', 1.15)):
    comp(n, 'Level', kind=8, position=p3(8.25, 4.3, z), dimensions=p3(.4, 4.2, .3), tint=STONE)
comp('TerraceLintel', 'Level', kind=8, position=p3(8.25, 6.6, 0), dimensions=p3(.4, .4, 2.6), tint=STONE)
comp('Planter', 'Level', kind=8, position=p3(10.6, 2.8, 1.4), dimensions=p3(1.6, .8, 1.2), tint=DARK)
comp('TreeTrunk', 'Level', kind=8, position=p3(10.6, 4.1, 1.4), dimensions=p3(.25, 1.8, .25), tint=col(.32, .24, .2))
node('TreeCanopy', 'Level', 'MeshInstance3D', position=p3(10.6, 5.2, 1.4), mesh='SubResource("CanopyMesh")', material_override='SubResource("Foliage")')

# Structural art (no gameplay): pier head, entry outpost, glowing destination doorway.
node('Structure', 'Level')
node('PierHead', 'Level/Structure', 'MeshInstance3D', position=p3(10.15, 1, 0), mesh='SubResource("PierHeadMesh")', material_override='SubResource("RingMaterial")')
node('PierNose', 'Level/Structure', 'MeshInstance3D', position=p3(12, 1, 0), rotation=v3(PI / 2, 0, 0), mesh='SubResource("PierNoseMesh")', material_override='SubResource("RingMaterial")')
node('EntryMass', 'Level/Structure', 'MeshInstance3D', position=p3(-10.15, -0.3, 0), mesh='SubResource("EntryMassMesh")', material_override='SubResource("RingMaterial")')
node('EntryPier', 'Level/Structure', 'MeshInstance3D', position=p3(-10.6, -25.8, 0), mesh='SubResource("EntryPierMesh")', material_override='SubResource("RingMaterial")')
for n, z in (('DoorGlowL', -0.99), ('DoorGlowR', 0.99)):
    node(n, 'Level/Structure', 'MeshInstance3D', position=p3(8.25, 4.7, z), mesh='SubResource("JambGlowMesh")', material_override='SubResource("WarmLine")')
node('DoorGlowTop', 'Level/Structure', 'MeshInstance3D', position=p3(8.25, 6.39, 0), mesh='SubResource("LintelGlowMesh")', material_override='SubResource("WarmLine")')

ext = ('[ext_resource type="Script" path="res://runtime/monument.gd" id="1"]\n'
       '[ext_resource type="Script" path="res://authoring/level.gd" id="2"]\n'
       '[ext_resource type="Script" path="res://authoring/component.gd" id="3"]\n')
out = '[gd_scene load_steps=%d format=3]\n\n%s\n%s\n%s' % (3 + len(res) + 1, ext, '\n'.join(res), '\n'.join(nodes))
import pathlib
target = pathlib.Path(__file__).resolve().parents[1] / 'monuments' / 'the_ring.tscn'
target.write_text(out, encoding='utf-8', newline='\n')
print('wrote', target, 'nodes', len(nodes), 'subresources', len(res))
