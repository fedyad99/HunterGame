shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.12, 0.20, 0.06);
uniform vec3 tip_color : source_color = vec3(0.42, 0.45, 0.18);

varying float vh;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vh = VERTEX.y;
	float ph = origin.x * 0.3 + origin.z * 0.21;
	float w = sin(TIME * 2.0 + ph) * 0.5 + sin(TIME * 3.3 + ph * 1.9) * 0.3;
	VERTEX.x += w * 0.12 * VERTEX.y;
	VERTEX.z += w * 0.07 * VERTEX.y;
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, clamp(vh * 1.6, 0.0, 1.0));
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.2, 0.25, 0.08);
}
