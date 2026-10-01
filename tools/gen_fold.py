"""Generates monuments/the_fold.tscn: the Spatial Links prototype (experimental,
docs/designs/2026-10-01-spatial-links.md). The scene is data; edit it here, not by hand.
Run from anywhere: python tools/gen_fold.py

Layout (x1 units below, built at SCALE): an entry deck (west), a square frame turning about the
X axis with a walkable deck on one inner side, a fixed screen with a slot east of the frame, and
a goal wall further east. Three doorways: A on the entry, B on the frame deck, C on the goal
wall. No ordinary path joins any two pieces; every crossing is a link.
- B is seen from the entry only through the frame's west window, which lines up in state 0.
- C is seen only through the fixed slot, which lines up with the frame deck in state 1 (the
  player's eye moves with the frame, so only fixed geometry can tell the states apart).
"""
import math, pathlib

SCALE = 4
PI = math.pi

def g(x): return x * SCALE
def num(x): return '%g' % x
def v3(x, y, z): return 'Vector3(%g, %g, %g)' % (x, y, z)
def p3(x, y, z): return v3(g(x), g(y), g(z))
def col(r, gg, b, a=1): return 'Color(%g, %g, %g, %g)' % (r, gg, b, a)
def transform_x(angle, origin):
    """Transform3D text for a rotation about +X by `angle`, then `origin` (scaled)."""
    c, s = math.cos(angle), math.sin(angle)
    x, y, z = (g(v) for v in origin)
    # Text form lists basis rows: rotation about X has rows (1,0,0), (0,c,-s), (0,s,c).
    return 'Transform3D(1, 0, 0, 0, %.6f, %.6f, 0, %.6f, %.6f, %g, %g, %g)' % (c, -s, s, c, x, y, z)

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

DARK = col(.23, .23, .26); STONE = col(.17, .17, .2); FRAME = col(.15, .14, .18)
sub('StandardMaterial3D', 'GoalLight', albedo_color=col(1, .93, .85), emission_enabled='true', emission=col(1, .91, .82), emission_energy_multiplier=2.5)
sub('BoxMesh', 'BeamMesh', size=v3(.64, 160, .64))
sub('BoxMesh', 'PlateMesh', size=v3(g(1.2), .04, g(1.2)))
# Legibility (playtest: start and end looked alike): a warm lantern marks the entry, an accent
# stripe marks the frame's deck side, a warm rim marks the west window, signs name the doorways.
sub('StandardMaterial3D', 'Lantern', albedo_color=col(1, .72, .42), emission_enabled='true', emission=col(1, .66, .34), emission_energy_multiplier=2.2)
sub('StandardMaterial3D', 'DeckMark', albedo_color=col(.55, .9, 1), emission_enabled='true', emission=col(.5, .88, 1), emission_energy_multiplier=1.4)
sub('StandardMaterial3D', 'SignLight', albedo_color=col(.95, .95, 1), emission_enabled='true', emission=col(.9, .93, 1), emission_energy_multiplier=1.6)
sub('BoxMesh', 'LanternMesh', size=p3(.6, .6, .6))
sub('BoxMesh', 'OuterStripe', size=v3(g(8), .08, g(.6)))
sub('BoxMesh', 'DeckEdge', size=v3(g(8), .06, g(.08)))
sub('BoxMesh', 'RimAcross', size=v3(.08, .12, g(2.4)))
sub('BoxMesh', 'RimUp', size=v3(.08, g(2.6), .12))
sub('CylinderMesh', 'SignDisc', top_radius=num(g(.45)), bottom_radius=num(g(.45)), height=num(g(.08)), radial_segments=32)
sub('BoxMesh', 'SignDiamond', size=p3(.08, .6, .6))
sub('BoxMesh', 'SignBar', size=p3(.08, .15, .8))
ACCENT = col(.55, .9, 1)

# Doorways: x1 width and height; reach to prime one.
DOOR_W, DOOR_H, REACH = 1.6, 2.6, 2.0
def doorway(name, parent, at, out, up=(0, 1, 0)):
    comp(name, parent, kind=9, label='"%s"' % name, position=p3(*at), path='NodePath("..")',
         travel_direction=v3(*out), ground_normal=v3(*up), width=num(g(DOOR_W)), aperture_height=num(g(DOOR_H)),
         trigger_radius=num(g(REACH)), link_group='"fold"', tint=ACCENT)
    # A sign above the lintel, flat in the doorway's plane (these doorways face along X): disc
    # for A, diamond for B, two bars for C. Readable in both views.
    holder = '%s/%s' % (parent, name)
    top = g(DOOR_H + .75)
    if name == 'A':
        node('Sign', holder, 'MeshInstance3D', position=v3(0, top, 0), rotation=v3(0, 0, PI / 2), mesh='SubResource("SignDisc")', material_override='SubResource("SignLight")', cast_shadow=0)
    elif name == 'B':
        node('Sign', holder, 'MeshInstance3D', position=v3(0, top, 0), rotation=v3(PI / 4, 0, 0), mesh='SubResource("SignDiamond")', material_override='SubResource("SignLight")', cast_shadow=0)
    else:
        for k, dy in (('SignUpper', .18), ('SignLower', -.18)):
            node(k, holder, 'MeshInstance3D', position=v3(0, top + g(dy), 0), mesh='SubResource("SignBar")', material_override='SubResource("SignLight")', cast_shadow=0)

QUESTION = "Which doorway should you join before you turn the frame?"
EXPLANATION = ("Join the entry doorway to the doorway on the frame while you can still see it, then turn the frame: "
               "the doorway goes with it, and the same link now opens onto a deck that has become a wall. "
               "From there the fixed slot shows the last doorway; join it to the frame's doorway and walk through.")
HINTS = ["A link stays with the architecture that holds its doorway.",
         "Join A to B first. Turning the frame afterwards carries B, and the link, with it.",
         "Link A to B, turn the frame once, walk through A, look back out through B and the slot, link B to C, cross."]

node('Puzzle', None, script='1')
node('Level', '.', script='2',
     level_id='"the_fold"', revision=1, title='"The fold"',
     question='"%s"' % QUESTION, explanation='"%s"' % EXPLANATION,
     overview_focus=p3(3, 0, -1), overview_size=num(g(40)),
     overview_azimuth_degrees=-50, overview_elevation_degrees=40,
     sweep_tolerance=num(.04 * SCALE), discovery_range=num(g(40)),
     hints='PackedStringArray(%s)' % ', '.join('"%s"' % h for h in HINTS))

# Entry (west): upright deck, top at y = -3, doorway A at its east edge facing the frame.
comp('Entry', 'Level', kind=0, label='"Entry"', position=p3(-11, -3, 0), dimensions=p3(6, .8, 2.4), end_sockets='false', tint=DARK)
comp('PlayerStart', 'Level/Entry', kind=4, position=p3(-2, 0, 0), path='NodePath("..")')
doorway('A', 'Level/Entry', (3, 0, 0), (1, 0, 0))
comp('EntryPier', 'Level', kind=8, position=p3(-11, -3.8 - 25, 0), dimensions=p3(1.2, 50, 1.2), tint=STONE)
# The start is marked by a warm lantern on a post beside the entry deck (the goal has the shaft).
comp('LanternPost', 'Level', kind=8, position=p3(-13.4, -3 + 1.6, 1.8), dimensions=p3(.3, 3.2, .3), tint=STONE)
node('Lantern', 'Level/LanternPost', 'MeshInstance3D', position=p3(0, 1.9, 0), mesh='SubResource("LanternMesh")', material_override='SubResource("Lantern")', cast_shadow=0)

# The frame: a square tube along X turning about X. Its walkable deck is a raised strip on the
# inner bottom side; doorway B at the deck's east end.
comp('Frame', 'Level', kind=3, label='"The frame"', axis=v3(1, 0, 0), initial_state=0, duration=1.8, tint=ACCENT)
comp('FrameDeck', 'Level/Frame', kind=0, label='"Frame deck"', position=p3(0, -3, 0), dimensions=p3(8, .8, 2.4), end_sockets='false', tint=DARK)
doorway('B', 'Level/Frame/FrameDeck', (4, 0, 0), (1, 0, 0))
comp('FrameBottom', 'Level/Frame', kind=8, position=p3(0, -3.8, 0), dimensions=p3(8, .8, 7.6), tint=FRAME)
# The deck side is marked: an accent stripe outside (seen from the overview wherever the frame is
# turned) and accent edges along the deck inside (the floor reads as a floor, even on a wall).
node('DeckStripe', 'Level/Frame', 'MeshInstance3D', position=v3(0, g(-4.2) - .05, 0), mesh='SubResource("OuterStripe")', material_override='SubResource("DeckMark")', cast_shadow=0)
for k, z in (('DeckEdgeNorth', -1.25), ('DeckEdgeSouth', 1.25)):
    node(k, 'Level/Frame', 'MeshInstance3D', position=v3(0, g(-3) + .03, g(z)), mesh='SubResource("DeckEdge")', material_override='SubResource("DeckMark")', cast_shadow=0)
comp('FrameTop', 'Level/Frame', kind=8, position=p3(0, 3.4, 0), dimensions=p3(8, .8, 7.6), tint=FRAME)
for name, z in (('FrameNorth', -3.4), ('FrameSouth', 3.4)):
    comp(name, 'Level/Frame', kind=8, position=p3(0, 0, z), dimensions=p3(8, 6, .8), tint=FRAME)
# West cap with a window low on the deck side: the entry sees B through it only in state 0.
WIN_Y = (-3.0, -0.4); WIN_Z = 1.2; CAP_X = -4.2; CAP_T = .4
def cap_box(name, y0, y1, z0, z1):
    comp(name, 'Level/Frame', kind=8, position=p3(CAP_X, (y0 + y1) / 2, (z0 + z1) / 2), dimensions=p3(CAP_T, y1 - y0, z1 - z0), tint=FRAME)
cap_box('WestCapTop', WIN_Y[1], 3.8, -3.8, 3.8)
cap_box('WestCapBottom', -3.8, WIN_Y[0], -3.8, 3.8)
cap_box('WestCapNorth', WIN_Y[0], WIN_Y[1], -3.8, -WIN_Z)
cap_box('WestCapSouth', WIN_Y[0], WIN_Y[1], WIN_Z, 3.8)
# A warm rim around the west window, on the cap's outer face (clear of the deck's end): arriving
# on the deck you face it, a light framing the tube's end; from the entry it frames the window.
RIM_X = g(CAP_X - CAP_T / 2) - .06
for k, y in (('RimTop', WIN_Y[1]), ('RimBottom', WIN_Y[0])):
    node(k, 'Level/Frame', 'MeshInstance3D', position=v3(RIM_X, g(y), 0), mesh='SubResource("RimAcross")', material_override='SubResource("Lantern")', cast_shadow=0)
for k, z in (('RimNorth', -WIN_Z), ('RimSouth', WIN_Z)):
    node(k, 'Level/Frame', 'MeshInstance3D', position=v3(RIM_X, g((WIN_Y[0] + WIN_Y[1]) / 2), g(z)), mesh='SubResource("RimUp")', material_override='SubResource("Lantern")', cast_shadow=0)

# Fixed screen east of the frame with a slot that lines up with the frame deck in state 1
# (deck on the north side, z = -3): through it, and only through it, C can be seen.
SCREEN_X = 5.2; SLOT_Y = 1.4; SLOT_Z = (-3.0, -2.2); EDGE = 8
def screen_box(name, y0, y1, z0, z1):
    comp(name, 'Level', kind=8, position=p3(SCREEN_X, (y0 + y1) / 2, (z0 + z1) / 2), dimensions=p3(.4, y1 - y0, z1 - z0), tint=STONE)
screen_box('ScreenTop', SLOT_Y, EDGE, -EDGE, EDGE)
screen_box('ScreenBottom', -EDGE, -SLOT_Y, -EDGE, EDGE)
screen_box('ScreenNorth', -SLOT_Y, SLOT_Y, -EDGE, SLOT_Z[0])
screen_box('ScreenSouth', -SLOT_Y, SLOT_Y, SLOT_Z[1], EDGE)

# Goal wall (east): its ground faces +z, the same way the frame deck faces in state 1. Doorway C
# at its west edge faces back towards the slot.
GOAL_Z = -2.61 - DOOR_H / 2
# A broad terrace, unlike the narrow entry: the end looks like an arrival.
comp('GoalWall', 'Level', kind=0, label='"Goal terrace"', transform=transform_x(PI / 2, (18, 0, GOAL_Z)), dimensions=p3(8, .8, 5), end_sockets='false', tint=DARK)
comp('Goal', 'Level/GoalWall', kind=5, position=p3(2.5, 0, 0), path='NodePath("..")', trigger_radius=num(g(1.2)), tint=ACCENT)
# The goal's landmark: a glowing plate on the ground and a light shaft starting well above head
# height (the eye walks through the goal, never through the light).
node('Plate', 'Level/GoalWall/Goal', 'MeshInstance3D', position=v3(0, .02, 0), mesh='SubResource("PlateMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)
node('LightShaft', 'Level/GoalWall/Goal', 'MeshInstance3D', position=v3(0, g(2.5) + 80, 0), mesh='SubResource("BeamMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)
doorway('C', 'Level/GoalWall', (-4, 0, 0), (-1, 0, 0))

ext = ('[ext_resource type="Script" path="res://runtime/monument.gd" id="1"]\n'
       '[ext_resource type="Script" path="res://authoring/level.gd" id="2"]\n'
       '[ext_resource type="Script" path="res://authoring/component.gd" id="3"]\n')
out = '[gd_scene load_steps=%d format=3]\n\n%s\n%s\n%s' % (3 + len(res) + 1, ext, '\n'.join(res), '\n'.join(nodes))
target = pathlib.Path(__file__).resolve().parents[1] / 'monuments' / 'the_fold.tscn'
target.write_text(out, encoding='utf-8', newline='\n')
print('wrote', target, 'nodes', len(nodes))
