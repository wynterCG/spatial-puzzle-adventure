// Selection outline for movable structures: an inverted hull drawn just outside the mesh,
// so the structure's own faces, paving and edges stay fully readable.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float width = 0.04;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
