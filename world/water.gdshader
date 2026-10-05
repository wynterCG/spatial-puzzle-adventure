shader_type spatial;
// Falling water for blockout monuments (docs/designs/2026-10-02-the-spillway.md): translucent
// streaks scrolling down the mesh's UV (top to bottom). No simulation; meshes carry the shape.
render_mode blend_mix, cull_disabled, depth_draw_opaque, unshaded;

uniform vec4 colour : source_color = vec4(.78, .92, .95, .7);
uniform float speed = 1.5;
uniform float streaks = 12.0;

void fragment() {
	float x = UV.x * streaks;
	float lane = floor(x);
	float jitter = fract(sin(lane * 12.9898) * 43758.5453);
	float flow = fract(UV.y * 3.0 - TIME * speed * (.7 + .6 * jitter) + jitter);
	float streak = smoothstep(.0, .5, flow) * (1.0 - smoothstep(.5, 1.0, flow));
	float edge = smoothstep(.0, .25, fract(x)) * (1.0 - smoothstep(.75, 1.0, fract(x)));
	ALBEDO = colour.rgb + vec3(.18) * streak * edge;
	ALPHA = colour.a * (.55 + .45 * streak * edge);
}
