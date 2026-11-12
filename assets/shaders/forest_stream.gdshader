shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float wave = sin(world_pos.x * 1.9 - TIME * 1.7 + sin(world_pos.z * 2.2)) * 0.5 + 0.5;
	float current = sin(world_pos.x * 4.0 - TIME * 2.2 + world_pos.z * 3.3) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.17, 0.37, 0.34), vec3(0.40, 0.68, 0.60), wave * 0.35 + current * 0.12);
	ROUGHNESS = 0.24;
	SPECULAR = 0.45;
	ALPHA = 0.82;
}
