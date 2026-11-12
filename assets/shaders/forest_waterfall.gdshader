shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	float flow = UV.y * 7.0 - TIME * 1.8;
	float broad = noise2(vec2(UV.x * 7.0, flow * 0.8));
	float detail = noise2(vec2(UV.x * 23.0 + broad * 0.8, flow * 2.0));
	float water = smoothstep(0.28, 0.8, broad * 0.6 + detail * 0.4);
	float edge = smoothstep(0.0, 0.07, UV.x) * smoothstep(0.0, 0.07, 1.0 - UV.x);
	float foam = smoothstep(0.75, 1.0, UV.y) * (0.5 + detail * 0.5);
	ALBEDO = mix(vec3(0.20, 0.48, 0.49), vec3(0.80, 0.92, 0.86), clamp(water * 0.65 + foam * 0.6, 0.0, 1.0));
	EMISSION = ALBEDO * 0.10;
	ALPHA = edge * (0.65 + water * 0.20);
}
