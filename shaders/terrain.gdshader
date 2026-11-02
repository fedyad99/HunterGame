shader_type spatial;
render_mode cull_disabled;

// Процедурный материал рельефа. Маски приходят в цвете вершин:
// R — вариация травы, G — скала, B — песок, A — дорога.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_nrm : repeat_enable, hint_normal, filter_linear_mipmap;

varying vec3 wpos;
varying vec4 mask;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mask = COLOR;
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.21).r;
	float n2 = texture(noise_tex, wpos.xz * 0.027).r;
	float n3 = texture(noise_tex, wpos.xz * 0.0045 + vec2(0.37, 0.11)).r;
	vec3 grass_a = vec3(0.16, 0.25, 0.08);
	vec3 grass_b = vec3(0.30, 0.34, 0.12);
	vec3 dry = vec3(0.47, 0.42, 0.22);
	vec3 grass = mix(grass_a, grass_b, n2);
	grass = mix(grass, dry, smoothstep(0.55, 0.8, n3) * 0.55);
	grass *= 0.78 + n1 * 0.44;
	vec3 dirt = vec3(0.30, 0.23, 0.15) * (0.8 + n1 * 0.4);
	grass = mix(grass, dirt, smoothstep(0.62, 0.78, mask.r * 0.4 + n2 * 0.7) * 0.6);
	vec3 rock = mix(vec3(0.34, 0.33, 0.31), vec3(0.52, 0.50, 0.47), n1) * (0.8 + n2 * 0.35);
	vec3 sand = vec3(0.60, 0.54, 0.40) * (0.88 + n1 * 0.24);
	vec3 road = vec3(0.37, 0.31, 0.23) * (0.8 + n1 * 0.35);
	float rockm = smoothstep(0.25, 0.6, mask.g + (n1 - 0.5) * 0.4);
	float roadm = smoothstep(0.3, 0.7, mask.a + (n1 - 0.5) * 0.35);
	vec3 c = mix(grass, sand, mask.b);
	c = mix(c, rock, rockm);
	c = mix(c, road, roadm);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.8, rockm);
	NORMAL_MAP = texture(noise_nrm, wpos.xz * 0.35).rgb;
	NORMAL_MAP_DEPTH = mix(0.5, 1.4, rockm);
}
