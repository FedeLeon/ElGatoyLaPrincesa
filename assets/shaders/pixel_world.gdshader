shader_type canvas_item;
render_mode unshaded;

uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 virtual_resolution = vec2(426.0, 240.0);

void fragment() {
	vec2 pixel_uv = (floor(SCREEN_UV * virtual_resolution) + vec2(0.5)) / virtual_resolution;
	vec3 color = texture(world_screen, pixel_uv).rgb;
	// Subtle color bands unify painted textures, sprites and the remaining meshes.
	color = floor(color * 31.0 + 0.5) / 31.0;
	COLOR = vec4(color, 1.0);
}
