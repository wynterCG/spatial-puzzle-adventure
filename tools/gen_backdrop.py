"""Generates world/backdrop.tscn: far megastructure silhouettes rising out of the mist.
Scenery only (no gameplay). Seeded, so regenerating gives the same world.
Run from anywhere: python tools/gen_backdrop.py"""
import math, pathlib, random
rng = random.Random(7)
res = ['[sub_resource type="StandardMaterial3D" id="Stone"]\nalbedo_color = Color(0.2, 0.21, 0.25, 1)\nroughness = 0.9\n']
nodes = ['[node name="Backdrop" type="Node3D"]\n']
for i in range(26):
    angle = rng.random() * math.tau
    distance = rng.uniform(450, 1600)
    width = rng.uniform(40, 160)
    height = rng.uniform(250, 900)
    depth = width * rng.uniform(.4, 1.4)
    y = height * .5 - rng.uniform(250, 450)
    yaw = rng.random() * math.pi
    res.append('[sub_resource type="BoxMesh" id="Mass%02d"]\nsize = Vector3(%g, %g, %g)\n' % (i, width, height, depth))
    c, s = math.cos(yaw), math.sin(yaw)
    nodes.append('[node name="Mass%02d" type="MeshInstance3D" parent="."]\ntransform = Transform3D(%g, 0, %g, 0, 1, 0, %g, 0, %g, %g, %g, %g)\nmesh = SubResource("Mass%02d")\nmaterial_override = SubResource("Stone")\ncast_shadow = 0\n'
                 % (i, c, -s, s, c, math.cos(angle) * distance, y, math.sin(angle) * distance, i))
out = '[gd_scene load_steps=%d format=3]\n\n%s\n%s' % (len(res) + 1, '\n'.join(res), '\n'.join(nodes))
target = pathlib.Path(__file__).resolve().parents[1] / 'world' / 'backdrop.tscn'
target.parent.mkdir(exist_ok=True)
target.write_text(out, encoding='utf-8', newline='\n')
print('wrote', target)
