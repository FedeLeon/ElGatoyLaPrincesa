shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

void fragment() {
	float distance_to_center = length(UV - vec2(0.5));
	float edge = 1.0 - smoothstep(0.40, 0.50, distance_to_center);
	float ripple = sin(distance_to_center * 65.0 - TIME * 2.0);
	float foam = smoothstep(0.72, 0.98, ripple) * smoothstep(0.1, 0.35, distance_to_center);
	ALBEDO = mix(vec3(0.26, 0.55, 0.52), vec3(0.75, 0.91, 0.83), foam * 0.35);
	ALPHA = edge * 0.75;
}
