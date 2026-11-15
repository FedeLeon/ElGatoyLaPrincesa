shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D ground_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec2 texture_scale = vec2(1.0);
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	ALBEDO = texture(ground_texture, UV * texture_scale).rgb * tint.rgb;
	ROUGHNESS = 1.0;
}
