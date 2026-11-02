shader_type spatial;
render_mode cull_disabled;

// Листва/хвоя с лёгким покачиванием от ветра.
uniform vec3 color_a : source_color = vec3(0.10, 0.20, 0.08);
uniform vec3 color_b : source_color = vec3(0.17, 0.28, 0.10);
uniform float sway = 0.06;

varying float vh;
varying vec3 tint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vh = VERTEX.y;
	float ph = origin.x * 0.13 + origin.z * 0.17;
	float w = sin(TIME * 1.3 + ph) * 0.6 + sin(TIME * 2.7 + ph * 1.7) * 0.4;
	VERTEX.x += w * sway * max(VERTEX.y, 0.0) * 0.25;
	VERTEX.z += w * sway * 0.6 * max(VERTEX.y, 0.0) * 0.25;
	float r = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	tint = mix(color_a, color_b, r);
}

void fragment() {
	ALBEDO = tint * (0.75 + clamp(vh * 0.05, 0.0, 0.35));
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.15, 0.2, 0.05);
}
