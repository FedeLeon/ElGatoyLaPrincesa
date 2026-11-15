shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float pulse = 0.5 + 0.5 * sin(TIME * 5.5);
	float ring_radius = 0.66 + sin(TIME * 3.6) * 0.035;
	float ring = 1.0 - smoothstep(0.035, 0.085, abs(radius - ring_radius));
	float center = 1.0 - smoothstep(0.0, 0.16, radius);
	float alpha = max(ring * (0.30 + pulse * 0.22), center * 0.22);
	ALBEDO = mix(vec3(0.40, 0.72, 0.48), vec3(0.92, 0.79, 0.42), pulse * 0.7);
	EMISSION = vec3(0.27, 0.48, 0.24) * (0.3 + pulse * 0.55);
	ALPHA = alpha;
}
