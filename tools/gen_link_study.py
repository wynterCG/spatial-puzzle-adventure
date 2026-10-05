"""Generates monuments/link_study.tscn: the Spatial Links interaction study (experimental,
docs/designs/2026-10-01-spatial-links.md). The scene is data; edit it here, not by hand.
Run from anywhere: python tools/gen_link_study.py

Three doorways in one open space, nothing to turn, no puzzle: does standing at a doorway,
looking at another and pressing F feel obvious? A stands at the north edge of the plaza; B faces
it from a platform ahead (with the light); C faces it from a higher platform to the east.
"""
import pathlib

SCALE = 4

def g(x): return x * SCALE
def num(x): return '%g' % x
def v3(x, y, z): return 'Vector3(%g, %g, %g)' % (x, y, z)
def p3(x, y, z): return v3(g(x), g(y), g(z))
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

DARK = col(.23, .23, .26); STONE = col(.17, .17, .2); ACCENT = col(.55, .9, 1)
sub('StandardMaterial3D', 'GoalLight', albedo_color=col(1, .93, .85), emission_enabled='true', emission=col(1, .91, .82), emission_energy_multiplier=2.5)
sub('BoxMesh', 'BeamMesh', size=v3(.64, 160, .64))
sub('BoxMesh', 'PlateMesh', size=v3(g(1.2), .04, g(1.2)))

DOOR_W, DOOR_H, REACH = .8, 1.4, 2.0
def doorway(name, parent, at, out):
    comp(name, parent, kind=9, label='"%s"' % name, position=p3(*at), path='NodePath("..")',
         travel_direction=v3(*out), ground_normal=v3(0, 1, 0), width=num(g(DOOR_W)), aperture_height=num(g(DOOR_H)),
         trigger_radius=num(g(REACH)), link_group='"study"', initially_discovered='true', tint=ACCENT)

def platform(name, at, size, pier_depth=50):
    comp(name, 'Level', kind=0, label='"%s"' % name, position=p3(*at), dimensions=p3(*size), end_sockets='false', tint=DARK)
    comp(name + 'Pier', 'Level', kind=8, position=p3(at[0], at[1] - size[1] - pier_depth / 2, at[2]), dimensions=p3(1.2, pier_depth, 1.2), tint=STONE)

node('Puzzle', None, script='1')
node('Level', '.', script='2',
     level_id='"link_study"', revision=1, title='"Link study"',
     question='"Stand at a doorway, look at another, and join them."',
     explanation='"Standing at a doorway makes it the one you link from. Looking at another doorway shows the link before you make it; F joins them, and walking through one leads out of the other."',
     overview_focus=p3(4, 0, -6), overview_size=num(g(30)),
     overview_azimuth_degrees=-40, overview_elevation_degrees=45,
     discovery_range=num(g(40)),
     hints='PackedStringArray("Walk up to the doorway at the edge of the plaza.", "Look at the doorway across the gap and press F.", "Walk through the doorway you are standing at.")')

platform('Plaza', (0, 0, 0), (8, .8, 8))
comp('PlayerStart', 'Level/Plaza', kind=4, position=p3(0, 0, 2.5), forward=v3(0, 0, -1), path='NodePath("..")')
doorway('A', 'Level/Plaza', (0, 0, -4), (0, 0, -1))

platform('North', (0, 0, -14), (6, .8, 6))
doorway('B', 'Level/North', (0, 0, 3), (0, 0, 1))
comp('Goal', 'Level/North', kind=5, position=p3(0, 0, -1.5), path='NodePath("..")', trigger_radius=num(g(1.2)), tint=ACCENT)
node('Plate', 'Level/North/Goal', 'MeshInstance3D', position=v3(0, .02, 0), mesh='SubResource("PlateMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)
node('LightShaft', 'Level/North/Goal', 'MeshInstance3D', position=v3(0, g(2.5) + 80, 0), mesh='SubResource("BeamMesh")', material_override='SubResource("GoalLight")', cast_shadow=0)

platform('East', (13, 3, -4), (6, .8, 6))
doorway('C', 'Level/East', (-3, 0, 0), (-1, 0, 0))

ext = ('[ext_resource type="Script" path="res://runtime/monument.gd" id="1"]\n'
       '[ext_resource type="Script" path="res://authoring/level.gd" id="2"]\n'
       '[ext_resource type="Script" path="res://authoring/component.gd" id="3"]\n')
out = '[gd_scene load_steps=%d format=3]\n\n%s\n%s\n%s' % (3 + len(res) + 1, ext, '\n'.join(res), '\n'.join(nodes))
target = pathlib.Path(__file__).resolve().parents[1] / 'monuments' / 'link_study.tscn'
target.write_text(out, encoding='utf-8', newline='\n')
print('wrote', target, 'nodes', len(nodes))
