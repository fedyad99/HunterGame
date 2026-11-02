shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D nmap : repeat_enable, hint_normal, filter_linear_mipmap;
uniform vec3 deep_color : source_color = vec3(0.02, 0.09, 0.11);
uniform vec3 sky_color : source_color = vec3(0.28, 0.38, 0.42);

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 a = texture(nmap, wp.xz * 0.04 + vec2(TIME * 0.012, TIME * 0.007)).rgb;
	vec3 b = texture(nmap, wp.xz * 0.09 - vec2(TIME * 0.01, -TIME * 0.013)).rgb;
	NORMAL_MAP = normalize(mix(a, b, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color, sky_color, fres);
	ALPHA = mix(0.72, 0.96, fres);
	ROUGHNESS = 0.04;
	SPECULAR = 0.7;
}
