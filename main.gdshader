shader_type canvas_item;

uniform float stripe_width = 10.0;   // делай не меньше ~1
uniform float stripe_gap   = 20.0;
uniform float stripe_angle = -45.0;
uniform float uv_scale     = 1.0;

uniform vec4 stripe_color  : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 fill_color    : source_color = vec4(0.0, 0.0, 0.0, 0.0);

mat2 rot(float deg) {
    float a = deg * 3.14159265 / 180.0;
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

void vertex() {
    UV = VERTEX / uv_scale;
}

void fragment() {
    vec2 p = rot(stripe_angle) * UV;

    float period = stripe_width + stripe_gap;
    float stripe = mod(p.x, period);

    float edge = stripe_width;
    float fw = max(fwidth(stripe), 0.0001);
    float mask = 1.0 - smoothstep(edge - fw, edge + fw, stripe);

    COLOR = mix(fill_color, stripe_color, clamp(mask, 0.0, 1.0));
}
