shader_type canvas_item;
render_mode unshaded;

// Экран Godot 4: явно объявляем текстуру
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float hatch_scale      : hint_range(20.0, 200.0, 1.0) = 90.0;
uniform float stroke_softness  : hint_range(0.0, 0.5, 0.01)  = 0.12;
uniform float edge_strength    : hint_range(0.0, 3.0, 0.01)   = 1.3;
uniform float grain_strength   : hint_range(0.0, 1.0, 0.01)   = 0.35;
uniform float contrast         : hint_range(0.5, 2.0, 0.01)   = 1.1;
uniform float back_grain         : hint_range(0, 1.0, 0.01)   = 0.2;
uniform vec3 paper_color  : source_color = vec3(0.97, 0.97, 0.95);
uniform vec3 pencil_color : source_color = vec3(0.10, 0.10, 0.10);

// --- helpers ---

float rand(vec2 co, float seed) {
	return fract(sin(dot(co*seed, vec2(12.9898, 78.233))) * 43758.5453);
}

float stroke_stripes(vec2 uv, vec2 dir, float scale, float thickness) {
	dir = normalize(dir);
	float coord = dot(uv * scale, dir);
	float d = abs(fract(coord) - 0.5);

	float line = 1.0 - smoothstep(thickness, thickness + stroke_softness, d);
	return line;
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 base = texture(SCREEN_TEXTURE, SCREEN_UV);
	float lum = luminance(base.rgb);

	// немного крутим контраст
	lum = pow(lum, 1.0 / contrast);
	float shade = 1.0 - lum;

	vec2 uv = SCREEN_UV;

	// --- слои штриховки ---
	float h1 = stroke_stripes(uv, vec2( 1.0,  0.15), hatch_scale * 1.0, 0.35);
	float h2 = stroke_stripes(uv, vec2( 0.7,  0.7 ), hatch_scale * 0.8, 0.35);
	float h3 = stroke_stripes(uv, vec2( 0.1,  1.0 ), hatch_scale * 0.6, 0.32);
	float h4 = stroke_stripes(uv, vec2(-0.7,  0.7 ), hatch_scale * 0.45, 0.30);

	float hatch = 0.0;
	if (shade > 0.15) hatch = max(hatch, h1);
	if (shade > 0.35) hatch = max(hatch, h2);
	if (shade > 0.55) hatch = max(hatch, h3);
	if (shade > 0.75) hatch = max(hatch, h4);

	hatch *= shade;

	// --- контур (градиент яркости) ---

	// вот тут был косяк — теперь правильно:
	vec2 pixel_size = SCREEN_PIXEL_SIZE;

	vec3 c_l = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-pixel_size.x, 0.0)).rgb;
	vec3 c_r = texture(SCREEN_TEXTURE, SCREEN_UV + vec2( pixel_size.x, 0.0)).rgb;
	vec3 c_u = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, -pixel_size.y)).rgb;
	vec3 c_d = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0,  pixel_size.y)).rgb;

	float l_l = luminance(c_l);
	float l_r = luminance(c_r);
	float l_u = luminance(c_u);
	float l_d = luminance(c_d);

	vec2 grad;
	grad.x = l_r - l_l;
	grad.y = l_d - l_u;

	float edge = length(grad);
	edge = smoothstep(0.08, 0.25, edge) * edge_strength;

	// --- зерно ---
	float g = rand(uv * vec2(720.0, 480.0), float(int(TIME/0.25)));
	float grain = mix(1.0, g, grain_strength);

	float ink = clamp(hatch * grain + edge, 0.0, 1.0);

	vec3 col = mix(paper_color, base.rgb, ink);
	if (base == vec4(1.0,1.0,1.0,1.0)) COLOR = vec4(paper_color*mix(1.0,g = rand(uv * vec2(720.0, 480.0), 1),back_grain),1);
	else COLOR = vec4(col, base.a);
}
