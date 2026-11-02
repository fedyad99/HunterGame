shader_type canvas_item;
// Опьянение: двоение, покачивание и лёгкое размытие картинки.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	uv += vec2(sin(t * 0.9 + uv.y * 4.0), cos(t * 0.7 + uv.x * 3.0)) * 0.006 * amount;
	vec2 off = vec2(sin(t * 0.8), cos(t * 0.6)) * 0.018 * amount;
	vec3 a = textureLod(screen_tex, uv, amount * 1.5).rgb;
	vec3 b = textureLod(screen_tex, uv + off, amount * 1.5).rgb;
	vec3 c = mix(a, b, 0.45 * amount);
	float vig = smoothstep(0.9, 0.3, length(SCREEN_UV - 0.5));
	c *= mix(1.0, vig, amount * 0.6);
	COLOR = vec4(c, 1.0);
}
