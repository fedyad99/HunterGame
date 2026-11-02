shader_type spatial;
render_mode cull_disabled;

// Процедурный материал рельефа. Маски приходят в цвете вершин:
// R — вариация травы, G — скала, B — песок, A — дорога.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_nrm : repeat_enable, hint_normal, filter_linear_mipmap;

uniform sampler2D tex_grass : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_dirt : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_rock : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_sand : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D nrm_grass : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D nrm_rock : hint_normal, repeat_enable, filter_linear_mipmap;

varying vec3 wpos;
varying vec4 mask;
varying float swampm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mask = COLOR;
	swampm = UV2.x;
}

// текстура с гашением повторов: два масштаба вперемешку
vec3 tiled(sampler2D t, vec2 p, float k) {
	vec3 a = texture(t, p * k).rgb;
	vec3 b = texture(t, p * k * 0.19 + vec2(0.31, 0.57)).rgb;
	return mix(a, b, 0.4);
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.21).r;
	float n2 = texture(noise_tex, wpos.xz * 0.027).r;
	float n3 = texture(noise_tex, wpos.xz * 0.0045 + vec2(0.37, 0.11)).r;
	vec3 tg = tiled(tex_grass, wpos.xz, 0.3);
	vec3 td = tiled(tex_dirt, wpos.xz, 0.25);
	vec3 tr = tiled(tex_rock, wpos.xz, 0.2);
	vec3 ts = tiled(tex_sand, wpos.xz, 0.25);
	vec3 grass = tg * mix(vec3(0.75, 0.95, 0.7), vec3(1.15, 1.1, 0.8), n2);
	grass = mix(grass, td * vec3(1.1, 1.05, 0.8), smoothstep(0.55, 0.8, n3) * 0.5);
	grass = mix(grass, td, smoothstep(0.62, 0.78, mask.r * 0.4 + n2 * 0.7) * 0.5);
	vec3 rock = tr * (0.9 + n2 * 0.4) * 1.6;
	vec3 sand = ts * (0.9 + n1 * 0.25) * 1.15;
	vec3 road = td * vec3(0.85, 0.75, 0.6) * (0.85 + n1 * 0.3);
	float rockm = smoothstep(0.25, 0.6, mask.g + (n1 - 0.5) * 0.4);
	float roadm = smoothstep(0.3, 0.7, mask.a + (n1 - 0.5) * 0.35);
	vec3 c = mix(grass, sand, mask.b);
	c = mix(c, rock, rockm);
	c = mix(c, road, roadm);
	// болото: тёмная жижа, лужи блестят
	float sw = smoothstep(0.15, 0.6, swampm + (n1 - 0.5) * 0.35);
	float puddle = smoothstep(0.55, 0.7, n2 * 0.6 + n1 * 0.5) * sw;
	vec3 mud = td * vec3(0.42, 0.38, 0.26) * (0.8 + n1 * 0.3);
	vec3 moss = tg * vec3(0.55, 0.62, 0.35);
	vec3 swc = mix(mud, moss, smoothstep(0.45, 0.65, n1) * 0.6);
	swc = mix(swc, vec3(0.06, 0.07, 0.05), puddle * 0.8);
	c = mix(c, swc, sw * (1.0 - roadm));
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.95, 0.8, rockm), 0.12, puddle);
	SPECULAR = mix(0.5, 0.9, puddle);
	vec3 nm = mix(texture(nrm_grass, wpos.xz * 0.3).rgb, texture(nrm_rock, wpos.xz * 0.2).rgb, rockm);
	NORMAL_MAP = mix(nm, texture(noise_nrm, wpos.xz * 0.35).rgb, 0.25);
	NORMAL_MAP_DEPTH = mix(0.8, 1.4, rockm);
}
